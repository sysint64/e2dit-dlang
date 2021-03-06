module rpui.widget;

import std.container.array;
import std.math;

import rpui.primitives;
import rpui.view;
import rpui.cursor;
import rpui.widgets_container;
import rpui.events;
import rpui.widget_events;
import rpui.math;
import rpui.focus_navigator;
import rpui.widget_locator;
import rpui.widget_resolver;
import rpui.render.renderer;
import rpui.render.components : State;

import gapi.vec;

/// Interface for scrollable widgets.
interface Scrollable {
    void onMouseWheelHandle(in int dx, in int dy);

    void scrollToWidget(Widget widget);
}

/// For scrollable widgets and if this widget allow to focus elements.
interface FocusScrollNavigation : Scrollable {
    /**
     * Scroll to widget if it out of visible region.
     * Scroll on top border if widget above and bottom if below visible region.
     */
    void borderScrollToWidget(Widget widget);
}

class Widget : EventsListenerEmpty {
    /// Type of sizing for width and height.
    enum SizeType {
        value,  /// Using value from size.
        wrapContent,  /// Automatically resize widget by content boundary.
        matchParent  /// Using parent size.
    }

    /**
     * Field attribute need to tell RPDL which fields are fill
     * when reading layout file.
     */
    struct field {
        string name = "";  /// Override name of variable.
    }

    @field bool isVisible = true;
    @field bool isEnabled = true;
    @field bool focusable = true;

    /// If true, then focus navigation by children will be limited inside this widget.
    @field bool finalFocus = false;

    /// Specifies the type of cursor to be displayed when pointing on an element.
    @field CursorIcon cursor = CursorIcon.normal;

    @field string name = "";

    /// Some help information about widget, need to display tooltip.
    @field utf32string hint = "";

    /// How to place a widget horizontally.
    @field Align locationAlign = Align.none;

    /// How to place a widget vertically.
    @field VerticalAlign verticalLocationAlign = VerticalAlign.none;

    /**
     * If set this option then widget will be pinned to one of the side
     * declared in the `basic_types.RegionAlign`.
     */
    @field RegionAlign regionAlign = RegionAlign.none;

    /// Used to create space around elements, outside of any defined borders.
    @field FrameRect margin = FrameRect(0, 0, 0, 0);

    /// Used to generate space around an element's content, inside of any defined borders.
    @field FrameRect padding = FrameRect(0, 0, 0, 0);

    @field vec2 position = vec2(0, 0);
    @field vec2 size = vec2(0, 0);

    @field SizeType widthType;  /// Determine how to set width for widget.
    @field SizeType heightType;  /// Determine how to set height for widget.

    @field
    @property float width() { return size.x; }
    @property void width(in float val) { size.x = val; }

    @field
    @property float height() { return size.y; }
    @property void height(in float val) { size.y = val; }

    @field
    @property float left() { return position.x; }
    @property void left(in float val) { position.x = val; }

    @field
    @property float top() { return position.y; }
    @property void top(in float val) { position.y = val; }

    @property size_t id() { return p_id; }
    private size_t p_id;

    /// Widget root rpdl node from where the data will be extracted.
    const string style;

    @property Widget parent() { return p_parent; }
    package Widget p_parent;

    // TODO(Andrey): package not working for the some reasons
    public Widget owner;

    @property inout(bool) isFocused() inout { return p_isFocused; }
    package bool p_isFocused;

    /// Next widget in `parent` children after this.
    @property Widget nextWidget() { return p_nextWidget; }
    package Widget p_nextWidget = null;

    /// Previous widget in `parent` children before this.
    @property Widget prevWidget() { return p_prevWidget; }
    package Widget p_prevWidget = null;

    /// Last widget in `parent` children.
    @property Widget lastWidget() { return p_lastWidget; }
    package Widget p_lastWidget = null;

    /// First widget in `parent` children.
    @property Widget firstWidget() { return p_firstWidget; }
    package Widget p_firstWidget = null;

    // TODO:
    @property ref WidgetsContainer children() { return p_children; }
    private WidgetsContainer p_children;

    @property uint depth() { return p_depth; }
    uint p_depth = 0;

    @property WidgetResolver resolver() { return p_resolver; }
    private WidgetResolver p_resolver;

    @property FocusNavigator focusNavigator() { return p_focusNavigator; }
    private FocusNavigator p_focusNavigator;

    @property WidgetEventsObserver events() { return p_events; }
    private WidgetEventsObserver p_events;

    /// Additional rules appart from `isVisible` to set widget visible or not.
    Array!(bool delegate()) visibleRules;

    /// Additional rules appart from `enabled` to set widget enabled or not.
    Array!(bool delegate()) enableRules;

    /**
     * Which part of widget need to render, e.g. if it is a button
     * then `PartDraws.left` tell that only left side and center will be
     * rendered, this need for grouping rendering of widgets.
     *
     * As example consider this layout of grouping: $(I [button1|button2|button3|button4])
     *
     * for $(I button1) `PartDraws` will be $(B left), for $(I button2) and $(I button3) $(B center)
     * and for $(I button4) it will be $(B right).
     */
    package enum PartDraws {
        all,  /// Draw all parts - left, center and right.
        left,
        center,
        right
    }

    package PartDraws partDraws = PartDraws.all;

package:
    public @property View view() { return view_; }
    View view_;

    bool skipFocus = false;  /// Don't focus this element.
    bool drawChildren = true;
    FrameRect extraInnerOffset = FrameRect(0, 0, 0, 0);  /// Extra inner offset besides padding.
    FrameRect extraOuterOffset = FrameRect(0, 0, 0, 0);  /// Extra outer offset besides margin.
    bool overlay;
    vec2 overSize;
    Rect overlayRect = emptyRect;
    bool focusOnMousUp = false;

    bool isEnter;  /// True if pointed on widget.
    bool overrideIsEnter;  /// Override isEnter state i.e. ignore isEnter value and use overrided value.
    bool isClick;
    bool isMouseDown = false;

    WidgetLocator locator;
    Renderer renderer;

    /**
     * When in rect of element but if another element over this
     * isOver will still be true.
     */
    bool isOver;

    public @property inout(vec2) absolutePosition() inout { return absolutePosition_; }
    vec2 absolutePosition_ = vec2(0, 0);

    /// Size of boundary over childern clamped to size of widget as minimum boundary size.
    vec2 innerBoundarySizeClamped = vec2(0, 0);

    vec2 innerBoundarySize = vec2(0, 0);  /// Size of boundary over childern.
    vec2 contentOffset = vec2(0, 0);  /// Children offset relative their absolute positions.
    vec2 outerBoundarySize = vec2(0, 0); /// Full region size including inner offsets.

    Widget associatedWidget = null;

    /**
     * Returns string of state declared in theme.
     */
    @property inout(State) state() inout {
        if (isClick) {
            return State.click;
        } else if (isEnter || overrideIsEnter) {
            return State.enter;
        } else {
            return State.leave;
        }
    }

    /// Inner size considering the extra innter offsets and paddings.
    @property vec2 innerSize() {
        return size - innerOffsetSize;
    }

    /// Total inner offset size (width and height) considering the extra inner offsets and paddings.
    @property vec2 innerOffsetSize() {
        return vec2(
            padding.left + padding.right + extraInnerOffset.left + extraInnerOffset.right,
            padding.top + padding.bottom + extraInnerOffset.top + extraInnerOffset.bottom
        );
    }

    /// Inner padding plus and extra inner offsets.
    @property FrameRect innerOffset() {
        return FrameRect(
            padding.left + extraInnerOffset.left,
            padding.top + extraInnerOffset.top,
            padding.right + extraInnerOffset.right,
            padding.bottom + extraInnerOffset.bottom,
        );
    }

    /// Total size of extra inner offset (width and height).
    @property vec2 extraInnerOffsetSize() {
        return vec2(
            extraInnerOffset.left + extraInnerOffset.right,
            extraInnerOffset.top + extraInnerOffset.bottom
        );
    }

    @property vec2 extraInnerOffsetStart() {
        return vec2(extraInnerOffset.left, extraInnerOffset.top);
    }

    @property vec2 extraInnerOffsetEnd() {
        return vec2(extraInnerOffset.right, extraInnerOffset.bottom);
    }

    @property vec2 innerOffsetStart() {
        return vec2(innerOffset.left, innerOffset.top);
    }

    @property vec2 innerOffsetEnd() {
        return vec2(innerOffset.right, innerOffset.bottom);
    }

    /// Outer size considering the extra outer offsets and margins.
    @property vec2 outerSize() {
        return size + outerOffsetSize;
    }

    /// Total outer offset size (width and height) considering the extra outer offsets and margins.
    @property vec2 outerOffsetSize() {
        return vec2(
            margin.left + margin.right + extraOuterOffset.left + extraOuterOffset.right,
            margin.top + margin.bottom + extraOuterOffset.top + extraOuterOffset.bottom
        );
    }

    /// Total outer offset - margins plus extra outer offsets.
    @property FrameRect outerOffset() {
        return FrameRect(
            margin.left + extraOuterOffset.left,
            margin.top + extraOuterOffset.top,
            margin.right + extraOuterOffset.right,
            margin.bottom + extraOuterOffset.bottom,
        );
    }

    @property vec2 outerOffsetStart() {
        return vec2(outerOffset.left, outerOffset.top);
    }

    @property vec2 outerOffsetEnd() {
        return vec2(outerOffset.right, outerOffset.bottom);
    }

public:
    /// Default constructor with default `style`.
    this() {
        this.style = "";
        createComponents();
    }

    /// Construct with custom `style`.
    this(in string style) {
        this.style = style;
        createComponents();
    }

    package this(View view) {
        this.style = "";
        this.view_ = view;
        createComponents();
    }

    private void createComponents() {
        this.locator = new WidgetLocator(this);
        this.p_focusNavigator = new FocusNavigator(this);
        this.p_children = new WidgetsContainer(this);
        this.p_resolver = new WidgetResolver(this);
        this.p_events = new WidgetEventsObserver();
        this.renderer = new DummyRenderer();

        this.p_events.subscribe!BlurEvent(&onBlur);
        this.p_events.subscribe!FocusEvent(&onFocus);
    }

    void onProgress(in ProgressEvent event) {
        checkRules();
        updateBoundary();
        renderer.onProgress(event);
    }

    /// Update widget inner bounary and clamped boundary.
    protected void updateBoundary() {
        if (!drawChildren)
            return;

        innerBoundarySize = innerOffsetSize;

        foreach (Widget widget; children) {
            if (!widget.isVisible)
                continue;

            auto widgetFringePosition = vec2(
                widget.position.x + widget.outerSize.x + innerOffset.left,
                widget.position.y + widget.outerSize.y + innerOffset.top
            );

            if (widget.locationAlign != Align.none) {
                widgetFringePosition.x = 0;
            }

            if (widget.verticalLocationAlign != VerticalAlign.none) {
                widgetFringePosition.y = 0;
            }

            if (widget.regionAlign != RegionAlign.right &&
                widget.regionAlign != RegionAlign.top &&
                widget.regionAlign != RegionAlign.bottom)
            {
                innerBoundarySize.x = fmax(innerBoundarySize.x, widgetFringePosition.x);
            }

            if (widget.regionAlign != RegionAlign.bottom &&
                widget.regionAlign != RegionAlign.right &&
                widget.regionAlign != RegionAlign.left)
            {
                innerBoundarySize.y = fmax(innerBoundarySize.y, widgetFringePosition.y);
            }
        }

        innerBoundarySize += innerOffsetEnd;

        innerBoundarySizeClamped.x = fmax(innerBoundarySize.x, innerSize.x);
        innerBoundarySizeClamped.y = fmax(innerBoundarySize.y, innerSize.y);
    }

    void checkRules() {
        if (!visibleRules.empty) {
            isVisible = true;

            foreach (bool delegate() rule; visibleRules) {
                isVisible = isVisible && rule();
            }
        }

        if (!enableRules.empty) {
            isEnabled = true;

            foreach (bool delegate() rule; enableRules) {
                isEnabled = isEnabled && rule();
            }
        }
    }

    protected void reset() {
        if (associatedWidget !is null)
            associatedWidget.reset();
    }

    final Widget getNonDecoratorParent() {
        Widget currentParent = parent;
        bool isDecorator = parent.associatedWidget !is null;

        while (isDecorator) {
            currentParent = currentParent.parent;
            isDecorator = currentParent.associatedWidget !is null;
        }

        return currentParent;
    }

    void resetChildren() {
        foreach (Widget widget; children) {
            widget.reset();
        }
    }

    package final void collectOnProgressQueries() {
        view.onProgressQueries.insert(this);

        if (!drawChildren)
            return;

        foreach (Widget widget; children) {
            if (!widget.isVisible && !widget.processPorgress())
                continue;

            view.onProgressQueries.insert(widget);
            widget.collectOnProgressQueries();
        }
    }

    package bool processPorgress() {
        return !visibleRules.empty || !enableRules.empty;
    }

    /// Render widget in camera view.
    void onRender() {
        renderer.onRender();

        if (drawChildren) {
            renderChildren();
        }
    }

    void renderChildren() {
        if (!drawChildren)
            return;

        foreach (Widget child; children) {
            if (!child.isVisible)
                continue;

            child.onRender();
        }
    }

    /// Make focus for widget, and clear focus from focused widget.
    void focus() {
        events.notify(FocusEvent());

        if (view.focusedWidget != this && view.focusedWidget !is null)
            view.focusedWidget.blur();

        view.focusedWidget = this;
        p_isFocused = true;

        if (!this.skipFocus)
            focusNavigator.borderScrollToWidget();
    }

    /// Clear focus from widget
    void blur() {
        isClick = false;
        p_isFocused = false;
        view.unfocusedWidgets.insert(this);
    }

    void onCreate() {
        renderer.onCreate(this, style);
    }

    void onPostCreate() {
        foreach (Widget widget; children) {
            widget.onPostCreate();
        }
    }

    override void onMouseMove(in MouseMoveEvent event) {
        isClick = isEnter && isMouseDown;
    }

    override void onMouseUp(in MouseUpEvent event) {
        if ((isFocused && isEnter) || (!focusable && isEnter))
            events.notify(ClickEvent());
    }

    void onFocus(in FocusEvent event) {}

    void onBlur(in BlurEvent event) {}

    /// Override this method if need change behaviour when system cursor have to be changed.
    void onCursor() {
    }

    void onResize() {
    }

    void onClickActionInvoked() {
    }

    /// Determine if `point` is inside widget area.
    final bool pointIsEnter(in vec2i point) {
        const Rect rect = Rect(absolutePosition.x, absolutePosition.y, size.x, size.y);
        return pointInRect(point, rect);
    }

    /// This method invokes when widget size is updated.
    void updateSize() {
        if (widthType == SizeType.matchParent) {
            locationAlign = Align.none;
            size.x = parent.innerSize.x - outerOffsetSize.x;
            position.x = 0;
        }

        if (heightType == SizeType.matchParent) {
            verticalLocationAlign = VerticalAlign.none;
            size.y = parent.innerSize.y - outerOffsetSize.y;
            position.y = 0;
        }
    }

    /// Recalculate size and position of widget and children widgets.
    void updateAll() {
        locator.updateLocationAlign();
        locator.updateVerticalLocationAlign();
        locator.updateRegionAlign();
        locator.updateAbsolutePosition();
        updateBoundary();
        updateSize();
        renderer.onProgress(ProgressEvent(0));

        foreach (Widget widget; children) {
            if (widget.isVisible)
                widget.updateAll();
        }
    }

    void freezeUI(bool isNestedFreeze = true) {
        view.freezeUI(this, isNestedFreeze);
    }

    void unfreezeUI() {
        view.unfreezeUI(this);
    }

    bool isFrozen() {
        return view.isWidgetFrozen(this);
    }

    bool isFreezingSource() {
        return view.isWidgetFreezingSource(this);
    }
}
