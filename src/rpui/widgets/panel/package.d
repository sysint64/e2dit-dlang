module rpui.widgets.panel;

import std.container;
import std.algorithm.comparison;
import std.stdio;

import rpdl;

import rpui.basic_types;
import rpui.widget;
import rpui.scroll;
import rpui.input;
import rpui.view;
import rpui.cursor;
import rpui.render_objects;
import rpui.events;
import rpui.widget_events;
import rpui.math;

import rpui.widgets.panel.measure;
import rpui.widgets.panel.render;
import rpui.widgets.panel.split;
import rpui.widgets.panel.header;
import rpui.widgets.panel.scroll_button;

/**
 * Panel widget is the container for other widgets with scrolling,
 * resizing, allow change placement by drag and drop.
 */
class Panel : Widget, FocusScrollNavigation {
    enum Background {
        transparent,  /// Render without color.
        light,
        dark,
        action  /// Color for actions like OK, Cancel etc.
    }

    @field float minSize = 40;  /// Minimum size of panel.
    @field float maxSize = 999;  /// Maximum size of panel.
    @field Background background = Background.light;  /// Background color of panel.
    @field bool userCanResize = true;
    @field bool userCanHide = false;
    @field bool userCanDrag = false;

    /// If true, then panel is open and will be rendered all content else only header.
    @field bool isOpen = true;
    @field bool darkSplit = false;  /// If true, then panel split will be dark.
    @field bool showSplit = true;  /// If true, render panel split else no.

    @field bool showVerticalScrollButton = true;
    @field bool showHorizontalScrollButton = true;

    @field utf32string caption = "";

    package Measure measure;
    private RenderData renderData;
    private RenderTransforms renderTransforms;
    private vec2 lastSize = 0;

    package Split split;
    package Header header;
    package ScrollButton horizontalScrollButton = ScrollButton(Orientation.horizontal);
    package ScrollButton verticalScrollButton = ScrollButton(Orientation.vertical);

    this(in string style = "Panel") {
        super(style);
        skipFocus = true;
    }

    override void onRender() {
        render(this, view.theme, renderData, renderTransforms);
    }

    protected override void onCreate() {
        super.onCreate();

        measure = readMeasure(view.theme.tree.data, style);
        renderData = readRenderData(view.theme, style);
        header.attach(this);
        horizontalScrollButton.attach(this);
        verticalScrollButton.attach(this);
    }

    override void onProgress(in ProgressEvent event) {
        super.onProgress(event);

        split.isEnter = false;

        handleResize();
        header.onProgress();

        // Update render elements position and sizes
        locator.updateRegionAlign();
        locator.updateAbsolutePosition();

        updateInnerOffset();
        updateSize();

        with (horizontalScrollButton)
            contentOffset.x = visible ? scrollController.contentOffset : 0;

        with (verticalScrollButton)
            contentOffset.y = visible ? scrollController.contentOffset : 0;

        updateRenderTransforms(this, &renderTransforms, &renderData, &view.theme);

        if (!isFreezingSource() && !isFrozen()) {
            horizontalScrollButton.onProgress();
            verticalScrollButton.onProgress();
        } else {
            horizontalScrollButton.isEnter = false;
            verticalScrollButton.isEnter = false;
        }
    }

    override void updateSize() {
        if (isOpen) {
            updatePanelSize();

            horizontalScrollButton.updateSize();
            verticalScrollButton.updateSize();
        }

        with (horizontalScrollButton)
            contentOffset.x = visible ? scrollController.contentOffset : 0;

        with (verticalScrollButton)
            contentOffset.y = visible ? scrollController.contentOffset : 0;
    }

    private void updatePanelSize() {
        if (heightType == SizeType.wrapContent) {
            size.y = innerBoundarySize.y;
        }

        if (widthType == SizeType.wrapContent) {
            size.x = innerBoundarySize.x;
        }
    }

    /// Add extra inner offset depends of which elements are visible.
    protected void updateInnerOffset() {
        extraInnerOffset.left = 0;

        if (verticalScrollButton.visible) {
            extraInnerOffset.right = verticalScrollButton.width;
        } else {
            extraInnerOffset.right = 0;
        }

        if (horizontalScrollButton.visible) {
            extraInnerOffset.bottom = horizontalScrollButton.width;
        } else {
            extraInnerOffset.bottom = 0;
        }

        if (userCanHide) {
            extraInnerOffset.top = header.height;
        } else {
            extraInnerOffset.top = 0;
        }

        // Split extra inner offset
        if (userCanResize || showSplit) {
            const thickness = 1;

            switch (regionAlign) {
                case RegionAlign.top:
                    extraInnerOffset.bottom += thickness;
                    break;

                case RegionAlign.bottom:
                    extraInnerOffset.top += thickness;
                    break;

                case RegionAlign.right:
                    extraInnerOffset.left += thickness;
                    break;

                case RegionAlign.left:
                    extraInnerOffset.right += thickness;
                    break;

                default:
                    break;
            }
        }
    }

    // Resize panel when split is clicked.
    void handleResize() {
        if (!split.isClick)
            return;

        switch (regionAlign) {
            case RegionAlign.top:
                size.y = lastSize.y + view.mousePos.y - view.mouseClickPos.y;
                break;

            case RegionAlign.bottom:
                size.y = lastSize.y - view.mousePos.y + view.mouseClickPos.y;
                break;

            case RegionAlign.left:
                size.x = lastSize.x + view.mousePos.x - view.mouseClickPos.x;
                break;

            case RegionAlign.right:
                size.x = lastSize.x - view.mousePos.x + view.mouseClickPos.x;
                break;

            default:
                break;
        }

        if (regionAlign == RegionAlign.top || regionAlign == RegionAlign.bottom)
            size.y = clamp(size.y, minSize, maxSize);

        if (regionAlign == RegionAlign.left || regionAlign == RegionAlign.right)
            size.x = clamp(size.x, minSize, maxSize);

        parent.events.notify(ResizeEvent());
        view.rootWidget.updateAll();
    }

    /// Change system cursor when mouse entering split.
    override void onCursor() {
        if (!userCanResize || !isOpen || scrollButtonIsClicked)
            return;

        if (regionAlign == RegionAlign.top || regionAlign == RegionAlign.bottom) {
            const Rect rect = Rect(
                split.cursorRangeRect.left,
                split.cursorRangeRect.top - split.cursorRangeSize / 2.0f,
                split.cursorRangeRect.width,
                split.cursorRangeSize
            );

            if (pointInRect(view.mousePos, rect) || split.isClick) {
                view.cursor = CursorIcon.vDoubleArrow;
                split.isEnter = true;
                horizontalScrollButton.isEnter = false;
            }
        }
        else if (regionAlign == RegionAlign.left || regionAlign == RegionAlign.right) {
            const Rect rect = Rect(
                split.cursorRangeRect.left - split.cursorRangeSize / 2.0f,
                split.cursorRangeRect.top,
                split.cursorRangeSize,
                split.cursorRangeRect.height
            );

            if (pointInRect(view.mousePos, rect) || split.isClick) {
                view.cursor = CursorIcon.hDoubleArrow;
                split.isEnter = true;
                verticalScrollButton.isEnter = false;
            }
        }
    }

    private bool scrollButtonIsClicked() {
        return verticalScrollButton.isClick || horizontalScrollButton.isClick;
    }

    override void scrollToWidget(Widget widget) {
        const vec2 relativePosition = widget.absolutePosition -
            (absolutePosition + extraInnerOffsetStart);

        with (verticalScrollButton.scrollController)
            setOffsetInPx(relativePosition.y + contentOffset);

        with (horizontalScrollButton.scrollController)
            setOffsetInPx(relativePosition.x + contentOffset);
    }

    override void borderScrollToWidget(Widget widget) {
        const vec2 relativePosition = widget.absolutePosition -
            (absolutePosition + extraInnerOffsetStart);

        with (verticalScrollButton.scrollController) {
            const float innerVisibleSize = visibleSize - extraInnerOffsetSize.y;
            const float widgetScrollOffset = relativePosition.y + contentOffset;

            if (relativePosition.y < 0) {
                setOffsetInPx(widgetScrollOffset);
            } else if (relativePosition.y + widget.size.y > innerVisibleSize) {
                setOffsetInPx(widgetScrollOffset - innerVisibleSize + widget.size.y);
            }
        }

        with (horizontalScrollButton.scrollController) {
            const float innerVisibleSize = visibleSize - extraInnerOffsetSize.x;
            const float widgetScrollOffset = relativePosition.x + contentOffset;

            if (relativePosition.x < 0) {
                setOffsetInPx(widgetScrollOffset);
            } else if (relativePosition.x + widget.size.x > innerVisibleSize) {
                setOffsetInPx(widgetScrollOffset - innerVisibleSize + widget.size.x);
            }
        }
    }

    /// Set scroll value in px.
    void scrollToPx(in float x, in float y) {
        verticalScrollButton.scrollController.setOffsetInPx(x);
        horizontalScrollButton.scrollController.setOffsetInPx(y);
    }

    /// Add value to scroll in px.
    void scrollByPx(in float dx, in float dy) {
        verticalScrollButton.scrollController.addOffsetInPx(dx);
        horizontalScrollButton.scrollController.addOffsetInPx(dy);
    }

    /// Set scroll value in percent.
    void scrollToPercent(in float x, in float y) {
        verticalScrollButton.scrollController.setOffsetInPercent(x);
        horizontalScrollButton.scrollController.setOffsetInPercent(y);
    }

    final void open() {
        if (isOpen)
            return;

        size = lastSize;
        isOpen = true;
        view.rootWidget.updateAll();
    }

    final void close() {
        if (!isOpen)
            return;

        lastSize = size;
        size.y = header.height;
        isOpen = false;
        view.rootWidget.updateAll();

        horizontalScrollButton.scrollController.setOffsetInPercent(0);
        verticalScrollButton.scrollController.setOffsetInPercent(0);
    }

    /// Toggle visibility of panel. If `isOpen` then method will close panel else open.
    final void toggle() {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

// Events ------------------------------------------------------------------------------------------

    override void onMouseUp(in MouseUpEvent event) {
        verticalScrollButton.isClick = false;
        horizontalScrollButton.isClick = false;

        if (split.isClick) {
            split.isClick = false;
            unfreezeUI();
        }

        super.onMouseUp(event);
    }

    /// Handle mouse down event - avoid it if UI is forzen.
    override void onMouseDown(in MouseDownEvent event) {
        if (isFreezingSource() && view.isNestedFreeze)
            return;

        if (split.isEnter && isOpen && view.cursor != CursorIcon.inherit) {
            lastSize = size;
            split.isClick = true;
            freezeUI();
        }

        if (!isFreezingSource()) {
            verticalScrollButton.isClick = verticalScrollButton.isEnter;
            horizontalScrollButton.isClick = horizontalScrollButton.isEnter;

            verticalScrollButton.scrollController.onMouseDown(event);
            horizontalScrollButton.scrollController.onMouseDown(event);
        }

        onHeaderMouseDown();
        super.onMouseDown(event);
    }

    private void onHeaderMouseDown() {
        if (!header.isEnter || !userCanHide)
            return;

        toggle();
    }

    override void onResize() {
        horizontalScrollButton.scrollController.onResize();
        verticalScrollButton.scrollController.onResize();

        super.onResize();
    }

    protected override void onMouseWheelHandle(in int dx, in int dy) {
        if (isFreezingSource() && view.isNestedFreeze)
            return;

        Scrollable scrollable = cast(Scrollable) parent;

        int horizontalDelta = dx;
        int verticalDelta = dy;

        if (!verticalScrollButton.scrollController.addOffsetInPx(-verticalDelta*20)) {
            if (scrollable && parent.isOver && !parent.isFrozen()) {
                scrollable.onMouseWheelHandle(0, verticalDelta);
            }
        }

        if (!horizontalScrollButton.scrollController.addOffsetInPx(-horizontalDelta*20)) {
            if (scrollable && parent.isOver && !parent.isFrozen()) {
                scrollable.onMouseWheelHandle(horizontalDelta, 0);
            }
        }
    }
}
