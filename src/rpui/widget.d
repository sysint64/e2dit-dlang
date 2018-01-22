/**
 * Widget base interface.
 *
 * Copyright: © 2017 RedGoosePaws
 * License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
 * Authors: Andrey Kabylin
 */

module rpui.widget;

import std.container;
import std.conv;
import std.math;

import input;
import gapi;
import application;
import math.linalg;
import basic_types;

import rpui.manager;
import rpui.render_factory;
import rpui.render_objects;
import rpui.cursor;
import rpui.renderer;
import rpui.scroll;

/// Interface for scrollable widgets.
interface Scrollable {
    /// Handle mouse wheel scrolling.
    void onMouseWheelHandle(in int dx, in int dy);

    /// Scroll to particular widget.
    void scrollToWidget(Widget widget);
}

/**
 * For scrollable widgets and if this widget allow to focus elements.
 */
interface FocusScrollNavigation : Scrollable {
    /**
     * Scroll to widget if it out of visible region.
     * Scroll on top border if widget above and bottom if below visible region.
     */
    void borderScrollToWidget(Widget widget);
}

/**
 * Base class widget.
 */
class Widget {
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
    struct Field {
        string name = "";  /// Override name of variable.
    }

    alias Children = Array!Widget;

// Properties --------------------------------------------------------------------------------------

    @Field bool resizable = true;  /// User can change size of the widget.

    /// Don't draw skin of widget, e.g. if it's button then button will be transparent.
    @Field bool withoutSkin = false;

    @Field bool visible = true;
    @Field bool enabled = true;
    @Field bool focusable = true;  /// If true then widget can be focused.

    /// If true, then focus navigation by children will be limited inside this widget.
    @Field bool finalFocus = false;

    // TODO:
    // @Field bool autoWidth;
    // @Field bool autoHeight;

    /// Specifies the type of cursor to be displayed when pointing on an element.
    @Field Cursor.Icon cursor;

    @Field string name = "";
    // TODO:
    // @Field int tag = 0;

    /// Some help information about widget, need to display tooltip.
    @Field utfstring hint = "";

    /// How to place a widget horizontally.
    @Field Align locationAlign = Align.none;

    /// How to place a widget vertically.
    @Field VerticalAlign verticalLocationAlign = VerticalAlign.none;

    /**
     * If set this option then widget will be pinned to one of the side
     * declared in the `basic_types.RegionAlign`.
     */
    @Field RegionAlign regionAlign = RegionAlign.none;

    /// Used to create space around elements, outside of any defined borders.
    @Field FrameRect margin = FrameRect(0, 0, 0, 0);

    /// Used to generate space around an element's content, inside of any defined borders.
    @Field FrameRect padding = FrameRect(0, 0, 0, 0);

    @Field vec2 position = vec2(0, 0);
    @Field vec2 size = vec2(0, 0);  /// Width and height.

    @Field SizeType widthType;  /// Determine how to set width for widget.
    @Field SizeType heightType;  /// Determine how to set height for widget.

    /// Get `size` x component.
    @Field
    @property float width() { return size.x; }

    /// Set `size` x component.
    @property void width(in float val) { size.x = val; }

    /// Get `size` y component.
    @Field
    @property float height() { return size.y; }

    /// Set `size` y component.
    @property void height(in float val) { size.y = val; }

    /// Unique identifier.
    @property size_t id() { return p_id; }

    /// Widget root rpdl node from where the data will be extracted.
    @property string style() { return p_style; }
    @property Widget parent() { return p_parent; }
    @property bool isFocused() { return p_isFocused; }

    /// Next widget in `parent` children after this.
    @property Widget nextWidget() { return p_nextWidget; }

    /// Previous widget in `parent` children before this.
    @property Widget prevWidget() { return p_prevWidget; }

    /// Last widget in `parent` children.
    @property Widget lastWidget() { return p_lastWidget; }

    /// First widget in `parent` children.
    @property Widget firstWidget() { return p_firstWidget; }

    @property ref Children children() { return p_children; }

    @property uint depth() { return p_depth; }

package:
    @property Widget associatedWidget() { return p_associatedWidget; }
    @property RenderFactory renderFactory() { return manager.renderFactory; }

    /**
     * Returns string of state declared in theme.
     */
    @property inout(string) state() inout {
        if (isClick) {
            return "Click";
        } else if (isEnter) {
            return "Enter";
        } else {
            return "Leave";
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

private:
    Camera camera = null;
    Children p_children;

    size_t p_id;
    string p_style;
    Widget p_parent;
    uint p_depth = 0;

    // Navigation (for focus)
    Widget p_nextWidget = null;
    Widget p_prevWidget = null;
    Widget p_lastWidget = null;
    Widget p_firstWidget = null;

    Widget p_associatedWidget = null;

protected:
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
    enum PartDraws {
        all,  /// Draw all parts - left, center and right.
        left,
        center,
        right
    }

    Application app;
    Manager manager;
    PartDraws partDraws;

package:
    bool p_isFocused;
    bool skipFocus = false;  /// Don't focus this element.
    bool drawChildren = true;
    FrameRect extraInnerOffset = FrameRect(0, 0, 0, 0);  /// Extra inner offset besides padding.
    FrameRect extraOuterOffset = FrameRect(0, 0, 0, 0);  /// Extra outer offset besides margin.
    bool overlay;
    vec2 overSize;

    bool isEnter;  /// True if pointed on widget.
    bool isClick;

    /**
     * When in rect of element but if another element over this
     * isOver will still be true.
     */
    bool isOver;

    vec2 absolutePosition = vec2(0, 0);

    /// Size of boundary over childern clamped to size of widget as minimum boundary size.
    vec2 innerBoundarySizeClamped = vec2(0, 0);

    vec2 innerBoundarySize = vec2(0, 0);  /// Size of boundary over childern.
    vec2 contentOffset = vec2(0, 0);  /// Children offset relative their absolute positions.

    @property void associatedWidget(Widget val) { p_associatedWidget = val; }

// Event Listeners ---------------------------------------------------------------------------------

public:
    alias OnClickListener = void delegate(Widget);
    alias OnDblClickListener = void delegate(Widget);
    alias OnFocusListener = void delegate(Widget);
    alias OnBlurListener = void delegate(Widget);
    alias OnKeyPressedListener = void delegate(Widget, in KeyCode key);
    alias OnKeyReleasedListener = void delegate(Widget, in KeyCode key);
    alias OnTextEnteredListener = void delegate(Widget, in utfchar key);
    alias OnMouseMoveListener = void delegate(Widget, in uint x, in uint y);
    alias OnMouseWheelListener = void delegate(Widget, in uint dx, in uint dy);
    alias OnMouseEnterListener = void delegate(Widget, in uint x, in uint y);
    alias OnMouseLeaveListener = void delegate(Widget, in uint x, in uint y);
    alias OnMouseDownListener = void delegate(Widget, in uint x, in uint y, in MouseButton button);
    alias OnMouseUpListener = void delegate(Widget, in uint x, in uint y, in MouseButton button);

    OnClickListener onClickListener = null;
    OnDblClickListener onDblClickListener = null;
    OnFocusListener onFocusListener = null;
    OnBlurListener onBlurListener = null;
    OnKeyPressedListener onKeyPressedListener = null;
    OnKeyReleasedListener onKeyReleasedListener = null;
    OnTextEnteredListener onTextEnteredListener = null;
    OnMouseMoveListener onMouseMoveListener = null;
    OnMouseWheelListener onMouseWheelListener = null;
    OnMouseEnterListener onMouseEnterListener = null;
    OnMouseLeaveListener onMouseLeaveListener = null;
    OnMouseDownListener onMouseDownListener = null;
    OnMouseUpListener onMouseUpListener = null;

// Events triggers ---------------------------------------------------------------------------------

    /// Invoke event listener with name `event`.
    void triggerEvent(string event, T...)(T args) {
        auto listener = mixin("this.on" ~ event ~ "Listener");

        if (listener !is null) {
            listener(this, args);
        }
    }

    /// Invoke click event listener.
    alias triggerClick = triggerEvent!("Click");

    /// Invoke double click event listener.
    alias triggerDblClick = triggerEvent!("DblClick");

// Implementation ----------------------------------------------------------------------------------

    /// Default constructor with default `style`.
    this() {
        app = Application.getInstance();
    }

    /// Construct with custom `style`.
    this(in string style) {
        app = Application.getInstance();
        this.p_style = style;
    }

    /**
     * Find the first element that satisfying the `predicate`
     * traversing up through its ancestors.
     */
    final Widget closest(bool delegate(Widget) predicate) {
        Widget widget = this.parent;

        while (widget !is null) {
            if (predicate(widget))
                return widget;

            widget = widget.parent;
        }

        return null;
    }

    /**
     * Find the first element that satisfying the `predicate`
     * traversing down through its ancestors.
     */
    final Widget find(bool delegate(Widget) predicate) {
        foreach (Widget widget; children) {
            if (predicate(widget))
                return widget;

            Widget foundWidget = widget.find(predicate);

            if (foundWidget !is null)
                return foundWidget;
        }

        return null;
    }

    /// Invoke `find` method and filter by name.
    final Widget findWidgetByName(in string name) {
        return find(widget => widget.name == name);
    }

    /// Update widget inner bounary and clamped boundary.
    protected void updateBoundary() {
        if (!drawChildren)
            return;

        innerBoundarySize = innerOffsetSize;

        foreach (Widget widget; children) {
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

    /// Invoke onProgress in each of children widget.
    void onProgress() {
        if (!drawChildren)
            return;

        foreach (Widget widget; children) {
            if (!widget.visible)
                continue;

            widget.onProgress();
        }

        updateBoundary();
    }

    /// Render widget in camera view.
    void render(Camera camera) {
        this.camera = camera;

        if (!drawChildren)
            return;

        foreach (Widget widget; children) {
            if (!widget.visible)
                continue;

            widget.render(camera);
        }
    }

    /// Delete `widget` from view.
    void deleteWidget(Widget targetWidget) {
        deleteWidget(targetWidget.id);
    }

    /// Delete widget by `id`.
    void deleteWidget(size_t id) {
    }

    /// Insert `widget` in root view.
    void addWidget(Widget widget) {
        const index = manager.getNextIndex();
        widget.manager = manager;

        if (children.length == 0) {
            p_firstWidget = widget;
            p_lastWidget = widget;
        }

        // Links
        widget.p_parent = this;
        widget.p_nextWidget = p_firstWidget;
        widget.p_prevWidget = p_lastWidget;
        widget.p_depth = p_depth + 1;

        p_lastWidget.p_nextWidget = widget;
        p_firstWidget.p_prevWidget = widget;
        p_lastWidget = widget;

        // Insert
        children.insert(widget);
        manager.widgetOrdering.insert(widget);
        widget.onCreate();
    }

    /// Determine if `point` is inside widget area
    bool pointIsEnter(in vec2i point) {
        const Rect rect = Rect(absolutePosition.x, absolutePosition.y, size.x, size.y);
        return pointInRect(point, rect);
    }

    /// Make focus for widget, and clear focus from focused widget.
    void focus() {
        if (manager.focusedWidget != this && manager.focusedWidget !is null)
            manager.focusedWidget.blur();

        manager.focusedWidget = this;
        p_isFocused = true;

        if (!this.skipFocus)
            borderScrollToWidget();

        if (onFocusListener !is null)
            onFocusListener(this);
    }

    /// Clear focus from widget
    void blur() {
        manager.unfocusedWidgets.insert(this);
    }

// Handle focus navigation -------------------------------------------------------------------------

    private void borderScrollToWidget() {
        Widget parent = this.parent;

        while (parent !is null) {
            auto scrollable = cast(Scrollable) parent;
            auto focusScrollNavigation = cast(FocusScrollNavigation) parent;
            parent = parent.p_parent;

            if (scrollable is null)
                continue;

            if (focusScrollNavigation is null) {
                scrollable.scrollToWidget(this);
            } else {
                focusScrollNavigation.borderScrollToWidget(this);
            }
        }
    }

    // NOTE: navFocusFront and navFocusBack are symmetrical
    // focusNext and focusPrev too therefore potential code reduction
    protected void navFocusFront() {
        if (skipFocus && firstWidget !is null) {
            firstWidget.navFocusFront();
        } else {
            this.focus();
        }
    }

    /// Focus to the next widget.
    void focusNext() {
        if (skipFocus && isFocused) {
            navFocusFront();
            return;
        }

        if (p_parent.p_lastWidget != this) {
            this.p_nextWidget.navFocusFront();
        } else {
            if (p_parent.finalFocus) {
                p_parent.navFocusFront();
            } else {
                p_parent.focusNext();
            }
        }
    }

    protected void navFocusBack() {
        if (skipFocus && lastWidget !is null) {
            lastWidget.navFocusBack();
        } else {
            this.focus();
        }
    }

    /// Focus to the previous widget.
    void focusPrev() {
        if (skipFocus && isFocused) {
            navFocusBack();
            return;
        }

        if (p_parent.p_firstWidget != this) {
            this.p_prevWidget.navFocusBack();
        } else {
            if (p_parent.finalFocus) {
                p_parent.navFocusBack();
            } else {
                p_parent.focusPrev();
            }
        }
    }

// Events ------------------------------------------------------------------------------------------

    /// Invoke when widget will create.
    void onCreate() {
    }

    void onKeyPressed(in KeyCode key) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onKeyPressed(key);
            widget.triggerEvent!("KeyPressed")(key);
        }
    }

    void onKeyReleased(in KeyCode key) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onKeyReleased(key);
            widget.triggerEvent!("KeyReleased")(key);
        }
    }

    void onTextEntered(in utfchar key) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onTextEntered(key);
            widget.triggerEvent!("TextEntered")(key);
        }
    }

    void onMouseDown(in uint x, in uint y, in MouseButton button) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onMouseDown(x, y, button);

            if (widget.isEnter)
                widget.triggerEvent!("MouseDown")(x, y, button);
        }
    }

    void onMouseUp(in uint x, in uint y, in MouseButton button) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onMouseUp(x, y, button);

            if (widget.isEnter) {
                widget.triggerEvent!("MouseUp")(x, y, button);
                widget.triggerClick();
            }
        }
    }

    void onDblClick(in uint x, in uint y, in MouseButton button) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onDblClick(x, y, button);

            if (widget.isEnter)
                widget.triggerDblClick();
        }
    }

    void onMouseMove(in uint x, in uint y) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onMouseMove(x, y);

            if (widget.isEnter)
                widget.triggerEvent!("MouseMove")(x, y);
        }
    }

    void onMouseWheel(in int dx, in int dy) {
        foreach (Widget widget; children) {
            if (widget.isFrozen())
                continue;

            widget.onMouseWheel(dx, dy);

            if (widget.isEnter)
                widget.triggerEvent!("MouseWheel")(dx, dy);
        }
    }

    /// Override this method if need change behaviour when system cursor have to be changed.
    void onCursor() {
    }

    /// Invoke when widget resize.
    void onResize() {
        foreach (Widget widget; children) {
            widget.onResize();
        }
    }

    /// Invoke when user pressed enter on focused widget.
    void onClickActionInvoked() {
    }

package:
    void updateLocationAlign() {
        switch (locationAlign) {
            case Align.left:
                absolutePosition.x = parent.absolutePosition.x + parent.innerOffset.left +
                    outerOffset.left;
                break;

            case Align.right:
                absolutePosition.x = parent.absolutePosition.x + parent.size.x -
                    parent.innerOffset.right - outerOffset.right - size.x;
                break;

            case Align.center:
                const halfSize = (parent.innerSize.x - size.x) / 2;
                absolutePosition.x = parent.absolutePosition.x + parent.innerOffset.left
                    + floor(halfSize);
                break;

            default:
                break;
        }
    }

    void updateVerticalLocationAlign() {
        switch (verticalLocationAlign) {
            case VerticalAlign.top:
                absolutePosition.y = parent.absolutePosition.y + parent.innerOffset.top +
                    outerOffset.top;
                break;

            case VerticalAlign.bottom:
                absolutePosition.y = parent.absolutePosition.y + parent.size.y -
                    parent.innerOffset.bottom - outerOffset.bottom - size.y;
                break;

            case VerticalAlign.middle:
                const halfSize = (parent.innerSize.y - size.y) / 2;
                absolutePosition.y = parent.absolutePosition.y + parent.innerOffset.top +
                    floor(halfSize);
                break;

            default:
                break;
        }
    }

    /// This method invokes when widget size is updated.
    public void updateSize() {
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
        updateAbsolutePosition();
        updateLocationAlign();
        updateVerticalLocationAlign();
        updateRegionAlign();
        updateSize();

        foreach (Widget widget; children) {
            widget.updateAll();
        }

        updateBoundary();
        updateSize();
    }

    void updateRegionAlign() {
        if (regionAlign == RegionAlign.none)
            return;

        const FrameRect region = findRegion();
        const vec2 regionSize = vec2(
            parent.innerSize.x - region.right  - region.left - outerOffsetSize.x,
            parent.innerSize.y - region.bottom - region.top  - outerOffsetSize.y
        );

        switch (regionAlign) {
            case RegionAlign.client:
                size.x = regionSize.x;
                size.y = regionSize.y;
                position = vec2(region.left, region.top);
                break;

            case RegionAlign.top:
                size.x = regionSize.x;
                position = vec2(region.left, region.top);
                break;

            case RegionAlign.bottom:
                size.x = regionSize.x;
                position.x = region.left;
                position.y = parent.innerSize.y - outerSize.y - region.bottom;
                break;

            case RegionAlign.left:
                size.y = regionSize.y;
                position = vec2(region.left, region.top);
                break;

            case RegionAlign.right:
                size.y = regionSize.y;
                position.x = parent.innerSize.x - outerSize.x - region.right;
                position.y = region.top;
                break;

            default:
                break;
        }
    }

    FrameRect findRegion() {
        FrameRect region;

        foreach (Widget widget; parent.children) {
            if (widget == this)
                break;

            if (!widget.visible || widget.regionAlign == RegionAlign.none)
                continue;

            switch (widget.regionAlign) {
                case RegionAlign.top:
                    region.top += widget.size.y + widget.outerOffset.bottom;
                    break;

                case RegionAlign.left:
                    region.left += widget.size.x + widget.outerOffset.right;
                    break;

                case RegionAlign.bottom:
                    region.bottom += widget.size.y + widget.outerOffset.top;
                    break;

                case RegionAlign.right:
                    region.right += widget.size.x + widget.outerOffset.left;
                    break;

                default:
                    continue;
            }
        }

        return region;
    }

    @property Renderer renderer() { return manager.renderer; }

    this(Manager manager) {
        this.manager = manager;
        app = Application.getInstance();
    }

    void updateAbsolutePosition() {
        vec2 res = vec2(0, 0);
	Widget lastParent = parent;

        while (lastParent !is null) {
            res += lastParent.position - lastParent.contentOffset;
            res += lastParent.innerOffsetStart + lastParent.outerOffsetStart;
            lastParent = lastParent.parent;
        }

        absolutePosition = position + res + outerOffsetStart;
        absolutePosition.x = round(absolutePosition.x);
        absolutePosition.y = round(absolutePosition.y);
    }

    void freezeUI(bool isNestedFreeze = true) {
        this.manager.freezeUI(this, isNestedFreeze);
    }

    void unfreezeUI() {
        this.manager.unfreezeUI(this);
    }

    bool isFrozen() {
        return this.manager.isWidgetFrozen(this);
    }

    bool isFreezingSource() {
        return this.manager.isWidgetFreezingSource(this);
    }
}
