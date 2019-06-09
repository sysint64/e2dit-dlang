module rpui.view;

import std.path;
import std.file;
import std.container.array;
import std.container.slist;

import gapi.vec;
import gapi.opengl;
import gapi.shader;

import rpui.input;
import rpui.cursor;
import rpui.widget;
import rpui.events_observer;
import rpui.events;
import rpui.widget_events;
import rpui.primitives;
import rpui.math;
import rpui.theme;
import rpui.render.components : CameraView;
import rpui.resources.strings;

struct ViewShaders {
    ShaderProgram textureAtlasShader;
}

ViewShaders createViewShaders() {
    const vertexSource = readText(buildPath("res", "shaders", "transform_vertex.glsl"));
    const vertexShader = createShader("transform vertex shader", ShaderType.vertex, vertexSource);

    const texAtalsFragmentSource = readText(buildPath("res", "shaders", "texture_atlas_fragment.glsl"));
    const texAtlasFragmentShader = createShader("texture atlas fragment shader", ShaderType.fragment, texAtalsFragmentSource);
    auto texAtlasShader = createShaderProgram("texture atlas program", [vertexShader, texAtlasFragmentShader]);

    return ViewShaders(texAtlasShader);
}

struct ViewResources {
    StringsRes strings;
}

ViewResources createViewResources() {
    return ViewResources(
        new StringsRes()
    );
}

final class View : EventsListenerEmpty {
    Theme theme;
    EventsObserver events;
    package Array!Widget onProgressQueries;

    private Widget p_widgetUnderMouse = null;
    @property Widget widgetUnderMouse() { return p_widgetUnderMouse; }

    private Subscriber rootWidgetSubscriber;

    private uint lastIndex = 0;
    package Widget rootWidget;
    package Array!Widget frontWidgets;  // This widgets are drawn last.
    package Array!Widget frontWidgetsOrdering;  // This widgets are process firstly.
    package Widget focusedWidget = null;
    package Array!Widget widgetOrdering;
    package Array!Widget unfocusedWidgets;

    package SList!Widget freezeSources;
    package SList!bool isNestedFreezeStack;

    public CursorIcon cursor = CursorIcon.inherit;
    package vec2i mousePos = vec2i(-1, -1);
    package vec2i mouseClickPos = vec2i(-1, -1);
    private Array!Rect scissorStack;
    private uint viewportHeight;

    package CameraView cameraView;
    package ViewResources resources;
    private CursorManager cursorManager;

    private this() {
        events = new EventsObserver();
    }

    this(in string themeName, CursorManager cursorManager, ViewResources resources) {
        with (rootWidget = new Widget(this)) {
            isOver = true;
            finalFocus = true;
        }

        events = new EventsObserver();
        events.join(rootWidget.events);

        theme = createThemeByName(themeName);
        this.resources = resources;
        this.cursorManager = cursorManager;
    }

    this(in string themeName) {
        with (rootWidget = new Widget(this)) {
            isOver = true;
            finalFocus = true;
        }

        events = new EventsObserver();
        events.join(rootWidget.events);

        theme = createThemeByName(themeName);
        this.resources = createViewResources();
    }

    /// Invokes all `onProgress` of all widgets and `poll` widgets.
    void onProgress(in ProgressEvent event) {
        cursor = CursorIcon.inherit;

        onProgressQueries.clear();
        rootWidget.collectOnProgressQueries();

        foreach (Widget widget; frontWidgets) {
            if (!widget.visible && !widget.processPorgress())
                continue;

            widget.collectOnProgressQueries();
        }

        blur();

        foreach (Widget widget; onProgressQueries) {
            widget.onProgress(event);
        }

        foreach_reverse (Widget widget; onProgressQueries) {
            widget.onProgress(event);
        }

        poll();

        foreach (Widget widget; frontWidgets) {
            if (!widget.visible && !widget.processPorgress())
                continue;

            if (widget.isOver)
                cursor = CursorIcon.inherit;
        }

        rootWidget.updateAll();
        cursorManager.setIcon(cursor);
    }

    /// Renders all widgets inside `camera` view.
    void onRender(in RenderEvent event) {
        cameraView.mvpMatrix = event.camertMVPMatrix;
        cameraView.viewportWidth = event.viewportWidth;
        cameraView.viewportHeight = event.viewportHeight;

        rootWidget.size.x = event.viewportWidth;
        rootWidget.size.y = event.viewportHeight;

        rootWidget.onRender();

        foreach (Widget widget; frontWidgets) {
            if (widget.visible) {
                widget.onRender();
            }
        }
    }

    /**
     * Determines widgets states - check when widget `isEnter` (i.e. mouse inside widget area);
     * `isClick` (when user clicked to widget) and when widget is over i.e. mouse inside widget area
     * but widget can be overlapped by another widget.
     */
    private void poll() {
        rootWidget.isOver = true;
        auto widgetsOrderingChain = widgetOrdering ~ frontWidgetsOrdering;

        foreach (Widget widget; widgetsOrderingChain) {
            if (widget is null)
                continue;

            if (!widget.visible) {
                widget.isOver = false;
                widget.isEnter = false;
                widget.isClick = false;
                continue;
            }

            if (!isWidgetFrozen(widget)) {
                widget.onCursor();
            }

            widget.isEnter = false;

            const size = vec2(
                widget.overSize.x > 0 ? widget.overSize.x : widget.size.x,
                widget.overSize.y > 0 ? widget.overSize.y : widget.size.y
            );

            Rect rect;

            if (widget.overlayRect == emptyRect) {
                rect = Rect(widget.absolutePosition, size);
            } else {
                rect = widget.overlayRect;
            }

            widget.isOver = widget.parent.isOver && pointInRect(mousePos, rect);
        }

        p_widgetUnderMouse = null;
        Widget found = null;

        foreach_reverse (Widget widget; widgetsOrderingChain) {
            if (found !is null && !widget.overlay)
                continue;

            if (widget is null || !widget.isOver || !widget.visible)
                continue;

            if (isWidgetFrozen(widget))
                continue;

            if (found !is null) {
                found.isEnter = false;
                found.isClick = false;
            }

            if (widget.pointIsEnter(mousePos)) {
                widget.isEnter = true;
                p_widgetUnderMouse = widget;
                found = widget;

                if (cursor == CursorIcon.inherit) {
                    cursor = widget.cursor;
                }

                break;
            }
        }
    }

    /// Add `widget` to root children.
    void addWidget(Widget widget) {
        rootWidget.children.addWidget(widget);
    }

    /// Delete `widget` from root children.
    void deleteWidget(Widget widget) {
        rootWidget.children.deleteWidget(widget);
    }

    /// Delete widget by `id` from root children.
    void deleteWidget(in size_t id) {
        rootWidget.children.deleteWidget(id);
    }

    /// Push scissor to stack.
    package void pushScissor(in Rect scissor) {
        if (scissorStack.length == 0)
            glEnable(GL_SCISSOR_TEST);

        scissorStack.insertBack(scissor);
        applyScissor();
    }

    /// Pop scissor from stack.
    package void popScissor() {
        scissorStack.removeBack(1);

        if (scissorStack.length == 0) {
            glDisable(GL_SCISSOR_TEST);
        } else {
            applyScissor();
        }
    }

    /// Apply all scissors for clipping widgets in scissors areas.
    Rect applyScissor() {
        FrameRect currentScissor = scissorStack.back.absolute;

        if (scissorStack.length >= 2) {
            foreach (Rect scissor; scissorStack) {
                if (currentScissor.left < scissor.absolute.left)
                    currentScissor.left = scissor.absolute.left;

                if (currentScissor.top < scissor.absolute.top)
                    currentScissor.top = scissor.absolute.top;

                if (currentScissor.right > scissor.absolute.right)
                    currentScissor.right = scissor.absolute.right;

                if (currentScissor.bottom > scissor.absolute.bottom)
                    currentScissor.bottom = scissor.absolute.bottom;
            }
        }

        auto screenScissor = IntRect(currentScissor);
        screenScissor.top = viewportHeight - screenScissor.top - screenScissor.height;
        glScissor(screenScissor.left, screenScissor.top, screenScissor.width, screenScissor.height);

        return Rect(currentScissor);
    }

    /// Focusing next widget after the current focused widget.
    void focusNext() {
        if (focusedWidget !is null)
            focusedWidget.focusNavigator.focusNext();
    }

    /// Focusing previous widget before the current focused widget.
    void focusPrev() {
        if (focusedWidget !is null)
            focusedWidget.focusNavigator.focusPrev();
    }

// Events ------------------------------------------------------------------------------------------

    /**
     * Root widget to handle all events such as `onKeyPressed`, `onKeyReleased` etc.
     * Default is `rootWidget` but if UI was freeze by some widget (e.g. dialog window)
     * then source will be top of freeze sources stack.
     */
    @property
    private Widget eventRootWidget() {
        return freezeSources.empty ? rootWidget : freezeSources.front;
    }

    override void onKeyPressed(in KeyPressedEvent event) {
        if (focusedWidget !is null && isClickKey(event.key)) {
            focusedWidget.isClick = true;
        }
    }

    override void onKeyReleased(in KeyReleasedEvent event) {
        if (focusedWidget !is null && isClickKey(event.key)) {
            focusedWidget.isClick = false;
            focusedWidget.onClickActionInvoked();
            focusedWidget.events.notify(ClickEvent());
            focusedWidget.events.notify(ClickActionInvokedEvent());
        }
    }

    override void onMouseDown(in MouseDownEvent event) {
        mouseClickPos.x = event.x;
        mouseClickPos.y = event.y;

        foreach_reverse (Widget widget; widgetOrdering) {
            if (widget is null || isWidgetFrozen(widget))
                continue;

            if (widget.isEnter) {
                widget.isClick = true;
                widget.isMouseDown = true;

                if (!widget.focusOnMousUp)
                    widget.focus();

                break;
            }
        }
    }

    override void onMouseUp(in MouseUpEvent event) {
        foreach_reverse (Widget widget; widgetOrdering) {
            if (widget is null || isWidgetFrozen(widget))
                continue;

            if (widget.isEnter && widget.focusOnMousUp && widget.isMouseDown)
                widget.focus();

            widget.isClick = false;
            widget.isMouseDown = false;
        }
    }

    override void onMouseWheel(in MouseWheelEvent event) {
        int horizontalDelta = event.dx;
        int verticalDelta = event.dy;

        if (isKeyPressed(KeyCode.Shift)) { // Inverse
            horizontalDelta = event.dy;
            verticalDelta = event.dx;
        }

        Scrollable scrollable = null;
        Widget widget = widgetUnderMouse;

        // Find first scrollable widget
        while (scrollable is null && widget !is null) {
            if (isWidgetFrozen(widget))
                continue;

            scrollable = cast(Scrollable) widget;
            widget = widget.parent;
        }

        if (scrollable !is null)
            scrollable.onMouseWheelHandle(horizontalDelta, verticalDelta);
    }

    override void onMouseMove(in MouseMoveEvent event) {
        mousePos.x = event.x;
        mousePos.y = event.y;
    }

    override void onWindowResize(in WindowResizeEvent event) {
        viewportHeight = event.height;
    }

    private void blur() {
        foreach (Widget widget; unfocusedWidgets) {
            widget.p_isFocused = false;
            widget.events.notify(BlurEvent());
        }

        unfocusedWidgets.clear();
    }

    void moveWidgetToFront(Widget widget) {

        void moveChildrensToFrontOrdering(Widget parentWidget) {
            frontWidgetsOrdering.insert(parentWidget);

            foreach (Widget child; parentWidget.children) {
                moveChildrensToFrontOrdering(child);
            }
        }

        frontWidgets.insert(widget);
        moveChildrensToFrontOrdering(widget);
        widget.parent.children.deleteWidget(widget);
        widget.p_parent = rootWidget;
    }

    @property bool isNestedFreeze() {
        return !isNestedFreezeStack.empty && isNestedFreezeStack.front;
    }

    uint getNextIndex() {
        ++lastIndex  ;
        return lastIndex;
    }

    /**
     * Freez UI except `widget`.
     * If `nestedFreeze` is true then will be frozen all children of widget.
     */
    void freezeUI(Widget widget, in bool nestedFreeze = true) {
        silentPreviousEventsEmitter(widget);
        freezeSources.insert(widget);
        isNestedFreezeStack.insert(nestedFreeze);
        events.join(widget.events);
    }

    /**
     * Unfreeze UI where source of freezing is `widget`.
     */
    void unfreezeUI(Widget widget) {
        if (!freezeSources.empty && freezeSources.front == widget) {
            freezeSources.removeFront();
            isNestedFreezeStack.removeFront();
            unsilentPreviousEventsEmitter(widget);
            events.unjoin(widget.events);
        }
    }

    private void silentPreviousEventsEmitter(Widget widget) {
        if (freezeSources.empty) {
            events.silent(rootWidget.events);
        } else {
            events.silent(freezeSources.front.events);
        }
    }

    private void unsilentPreviousEventsEmitter(Widget widget) {
        if (freezeSources.empty) {
            events.unsilent(rootWidget.events);
        } else {
            events.unsilent(freezeSources.front.events);
        }
    }

    /**
     * Returns true if the `widget` is frozen.
     * If not `isNestedFreeze` then check if `widget` inside freezing source
     * And if `widget` has source parent then this widget is not frozen.
     */
    bool isWidgetFrozen(Widget widget) {
        if (freezeSources.empty || freezeSources.front == widget)
            return false;

        if (!isNestedFreeze) {
            auto freezeSourceParent = widget.resolver.closest(
                (Widget parent) => freezeSources.front == parent
            );
            return freezeSourceParent is null;
        } else {
            return true;
        }
    }

    bool isWidgetFreezingSource(Widget widget) {
        return !freezeSources.empty && freezeSources.front == widget;
    }
}
