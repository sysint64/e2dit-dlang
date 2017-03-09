module ui.widgets.panel;

import std.container;
import std.algorithm.comparison;
import std.stdio;

import basic_types;
import math.linalg;
import gapi;
import log;
import input;

import ui.widget;
import ui.scroll;
import ui.manager;
import ui.cursor;
import ui.render_objects;


class Panel : Widget {
    enum Background {transparent, light, dark, action};

    this(in string style) {
        super(style);
    }

    override void render(Camera camera) {
        // split.isEnter = false;
        float lastPaddingTop = padding.top;

        updateAbsolutePosition();
        updateRegionOffset();
	updateScroll();

        if (background != Background.transparent)
            renderer.renderColorQuad(backgroundRenderObject, backgroundColors[background],
                                     absolutePosition, size);

        calculateSplit();

        if (allowHide) {
        }

        if (!isOpen) {
            updateAlign();
            padding.top = lastPaddingTop;
            renderSplit();
            return;
        }

        pollHorizontalScroll();
        pollVerticalScroll();

        renderVerticalScroll();
        renderHorizontalScroll();

        // Render children
        Rect scissor;
        scissor.point = vec2(absolutePosition.x + regionOffset.left,
                             absolutePosition.y + regionOffset.top);
        scissor.size = vec2(size.x - regionOffset.left - regionOffset.right,
                            size.y - regionOffset.top - regionOffset.bottom);
        manager.pushScissor(scissor);

        if (split.isClick)
            pollSplitResize();

        super.render(camera);

        manager.popScissor();

        renderSplit();
	updateAlign();
    }

    override void onCreate() {
        renderFactory.createQuad(backgroundRenderObject);
        renderFactory.createQuad(splitBorderRenderObject);
        renderFactory.createQuad(splitInnerRenderObject);

        with (manager.theme) {
            // Panel background colors
            backgroundColors[Background.light]  = data.getNormColor(style ~ ".backgroundLight");
            backgroundColors[Background.dark]   = data.getNormColor(style ~ ".backgroundDark");
            backgroundColors[Background.action] = data.getNormColor(style ~ ".backgroundAction");

            // Split
            split.thickness = data.getNumber(style ~ ".Split.thickness.0");

            const auto addSplitColor = delegate(in string key) {
                splitColors[key] = manager.theme.data.getNormColor(style ~ "." ~ key);
            };

            addSplitColor(spliteState(false, false));
            addSplitColor(spliteState(false, true));
            addSplitColor(spliteState(true , false));
            addSplitColor(spliteState(true , true));

            // Scroll
            const string[3] states = ["Leave", "Enter", "Click"];
            const string[3] horizontalParts = ["left", "center", "right"];
            const string[3] verticalParts = ["top", "middle", "bottom"];

            const string scrollHorizontalBgStyle = style ~ ".Scroll.Horizontal";
            const string scrollVerticalBgStyle = style ~ ".Scroll.Vertical";
            const string scrollHorizontalButtonStyle = style ~ ".Scroll.Horizontal.Button";
            const string scrollVerticalButtonStyle = style ~ ".Scroll.Vertical.Button";

            with (verticalScrollButton) {
                // button and bg size.x
                const string buttonSelector = scrollVerticalButtonStyle ~ ".Leave.top.2";
                const string bgSelector = scrollVerticalBgStyle ~ ".middle.2";

                scrollController = new ScrollController(Orientation.vertical);
                scrollController.buttonMinSize = data.getNumber(buttonSelector) * 2;
                buttonWidth = data.getNumber(bgSelector);
            }

            with (horizontalScrollButton) {
                // button and bg size.y
                const string buttonSelector = scrollHorizontalButtonStyle ~ ".Leave.left.3";
                const string bgSelector = scrollHorizontalBgStyle ~ ".left.3";

                scrollController = new ScrollController(Orientation.horizontal);
                scrollController.buttonMinSize = data.getNumber(buttonSelector) * 2;
                buttonWidth = data.getNumber(bgSelector);
            }

            foreach (string part; verticalParts) {
                renderFactory.createQuad(verticalScrollButton.buttonRenderObjects,
                                         scrollVerticalButtonStyle, states, part);
            }

            foreach (string part; horizontalParts) {
                renderFactory.createQuad(horizontalScrollButton.buttonRenderObjects,
                                         scrollHorizontalButtonStyle, states, part);
            }
        }
    }

    override void onCursor() {
        if (!resizable || !isOpen || verticalScrollButton.isClick || horizontalScrollButton.isClick) {
            split.isEnter = false;
            return;
        }

        if (regionAlign == RegionAlign.top || regionAlign == RegionAlign.bottom) {
            const Rect rect = Rect(split.borderPosition.x,
                                   split.borderPosition.y - split.cursorRangeSize / 2.0f,
                                   split.size.x, split.cursorRangeSize);

            if (pointInRect(app.mousePos, rect) || split.isClick) {
                manager.cursor = Cursor.Icon.vDoubleArrow;
                split.isEnter = true;
            } else {
                split.isEnter = false;
            }
        } else if (regionAlign == RegionAlign.left || regionAlign == RegionAlign.right) {
            const Rect rect = Rect(split.borderPosition.x - split.cursorRangeSize / 2.0f,
                                   split.borderPosition.y,
                                   split.cursorRangeSize, split.size.y);

            if (pointInRect(app.mousePos, rect) || split.isClick) {
                manager.cursor = Cursor.Icon.hDoubleArrow;
                split.isEnter = true;
            } else {
                split.isEnter = false;
            }
        }
    }

    override void onMouseDown(in uint x, in uint y, in MouseButton button) {
        if (split.isEnter && isOpen) {
            lastSize = size;
            split.isClick = true;
        }

        verticalScrollButton.isClick = verticalScrollButton.isEnter;
        horizontalScrollButton.isClick = horizontalScrollButton.isEnter;

        verticalScrollButton.scrollController.onMouseDown(x, y, button);
        horizontalScrollButton.scrollController.onMouseDown(x, y, button);
    }

    override void onMouseUp(in uint x, in uint y, in MouseButton button) {
        super.onMouseDown(x, y, button);

        verticalScrollButton.isClick = false;
        horizontalScrollButton.isClick = false;
        split.isClick = false;
    }

    override void onMouseWheel(in int dx, in int dy) {
        if (!isEnter)
            return;

        verticalScrollButton.scrollController.onMouseWheel(dx, dy);
        horizontalScrollButton.scrollController.onMouseWheel(dx, dy);
    }

    // Properties ----------------------------------------------------------------------------------

    @property ref bool showVerticalScrollButton() { return p_showVerticalScrollButton; }
    @property ref bool showHorizontalScrollButton() { return p_showHorizontalScrollButton; }
    @property void showVerticalScrollButton(in bool val) { p_showVerticalScrollButton = val; }
    @property void showHorizontalScrollButton(in bool val) { p_showHorizontalScrollButton = val; }

    @property
    void showScrollButtons(in bool val) {
        p_showVerticalScrollButton = val;
        p_showHorizontalScrollButton = val;
    }

    @property ref utfstring caption() { return p_caption; }
    @property void caption(in utfstring val) { p_caption = val; }

    @property Background background() { return p_background; }
    @property void background(in Background val) { p_background = val; }

    @property ref bool allowResize() { return p_allowResize; }
    @property void allowResize(in bool val) { p_allowResize = val; }

    @property ref bool allowHide() { return p_allowHide; }
    @property void allowHide(in bool val) { p_allowHide = val; }

    @property ref bool allowDrag() { return p_allowDrag; }
    @property void allowDrag(in bool val) { p_allowDrag = val; }

    @property ref bool isOpen() { return p_isOpen; }
    @property void isOpen(in bool val) { p_isOpen = val; }

    @property ref bool blackSplit() { return p_blackSplit; }
    @property void blackSplit(in bool val) { p_blackSplit = val; }

    @property ref bool showSplit() { return p_showSplit; }
    @property void showSplit(in bool val) { p_showSplit = val; }

    @property ref float minSize() { return p_minSize; }
    @property void minSize(in float val) { p_minSize = val; }

    @property ref float maxSize() { return p_maxSize; }
    @property void maxSize(in float val) { p_maxSize = val; }

protected:
    override void updateAlign() {
        if (regionAlign == RegionAlign.none)
            return;

        const FrameRect region = findRegion();
        const vec2 scrollRegion = vec2(0, 0);  // TODO: make real region
        const vec2 regionSize = vec2(parent.size.x - region.right  - region.left - scrollRegion.x,
                                     parent.size.y - region.bottom - region.top  - scrollRegion.y);

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
                position.y = parent.size.y - size.y - region.bottom - scrollRegion.y;
                break;

            case RegionAlign.left:
                size.y = regionSize.y;
                position = vec2(region.left, region.top);
                break;

            case RegionAlign.right:
                size.y = regionSize.y;
                position.x = parent.size.x - size.x - region.right - scrollRegion.x;
                position.y = region.top;
                break;

            default:
                break;
        }
    }

    void updateRegionOffset() {
        if (verticalScrollButton.visible) {
            regionOffset.right = verticalScrollButton.buttonWidth;
        } else {
            regionOffset.right = 0;
        }

        if (horizontalScrollButton.visible) {
            regionOffset.bottom = horizontalScrollButton.buttonWidth;
        } else {
            regionOffset.right = 0;
        }
    }

private:
    BaseRenderObject splitBorderRenderObject;
    BaseRenderObject splitInnerRenderObject;
    BaseRenderObject headerRenderObject;
    BaseRenderObject expandArrowRenderObject;
    BaseRenderObject backgroundRenderObject;
    TextRenderObject textRenderObject;

    vec4[Background] backgroundColors;
    vec4[string] splitColors;

    vec2 widgetsOffset;
    static uint enteredSplitsCount = 0;

    struct Split {
        bool isClick = false;
        float thickness = 1;
        float cursorRangeSize = 8;
        Rect cursorRangeRect;
        vec2 borderPosition;
        vec2 innerPosition;
        vec2 size;

        @property ref bool isEnter() { return p_isEnter; }
        @property void isEnter(in bool val) {
            if (!val && p_isEnter)
                enteredSplitsCount -= 1;

            if (val && !p_isEnter)
                enteredSplitsCount += 1;

            p_isEnter = val;
        }

    private:
        bool p_isEnter = false;
    }

    Split split;

    float panelSize;
    float currentPanelSize;

    float headerSize = 0;
    bool headerIsEnter = false;

    struct ScrollButton {
        BaseRenderObject[string] backgroundRenderObjects;
        BaseRenderObject[string] buttonRenderObjects;
        ScrollController scrollController;
        float buttonWidth;

        bool isEnter = false;
        bool isClick = false;
        bool visible = true;

        @property string state() {
            if (isClick) {
                return "Click";
            } else if (isEnter){
                return "Enter";
            } else {
                return "Leave";
            }
        }
    }

    ScrollButton verticalScrollButton;
    ScrollButton horizontalScrollButton;

    Array!Widget joinedWidgets;

    //
    int p_scrollDelta = 20;
    float p_minSize = 40;
    float p_maxSize = 999;
    bool p_showVerticalScrollButton = true;
    bool p_showHorizontalScrollButton = true;
    Background p_background = Background.light;

    bool p_allowResize = false;
    bool p_allowHide = false;
    bool p_allowDrag = false;
    bool p_isOpen = true;
    bool p_blackSplit = false;
    bool p_showSplit = true;
    utfstring p_caption = "Hello World!";

    vec2 lastSize = 0;

    string spliteState(in bool innerColor, in bool useBlackColor = false) const {
        const string color = innerColor ? "innerColor" : "borderColor";
        return p_blackSplit || useBlackColor ? "Split.Dark." ~ color : "Split.Light." ~ color;
    }

    @property
    bool scrollButtonIsClicked() {
        return verticalScrollButton.isClick || horizontalScrollButton.isClick;
    }

    FrameRect findRegion() {
        FrameRect region;

        foreach (uint index, Widget widget; parent.children) {
            if (widget == this)
                break;

            if (!widget.visible || widget.regionAlign == RegionAlign.none)
                continue;

            switch (widget.regionAlign) {
                case RegionAlign.top:
                    region.top += widget.size.y;
                    break;

                case RegionAlign.left:
                    region.left += widget.size.x;
                    break;

                case RegionAlign.bottom:
                    region.bottom += widget.size.y;
                    break;

                case RegionAlign.right:
                    region.right += widget.size.x;
                    break;

                default:
                    continue;
            }
        }

        return region;
    }

    void updateScroll() {
    }

    void pollScroll() {
    }

    void pollSplitResize() {
        switch (regionAlign) {
            case RegionAlign.top:
                size.y = lastSize.y + app.mousePos.y - app.mouseClickPos.y;
                break;

            case RegionAlign.bottom:
                size.y = lastSize.y - app.mousePos.y + app.mouseClickPos.y;
                break;

            case RegionAlign.left:
                size.x = lastSize.x + app.mousePos.x - app.mouseClickPos.x;
                break;

            case RegionAlign.right:
                size.x = lastSize.x - app.mousePos.x + app.mouseClickPos.x;
                break;

            default:
                break;
        }

        if (regionAlign == RegionAlign.top || regionAlign == RegionAlign.bottom)
            size.y = clamp(size.y, minSize, maxSize);

        if (regionAlign == RegionAlign.left || regionAlign == RegionAlign.right)
            size.x = clamp(size.x, minSize, maxSize);
    }

    void calculateSplit() {
        if (!resizable && !showSplit)
            return;

        switch (regionAlign) {
            case RegionAlign.top:
                split.borderPosition = absolutePosition + vec2(0, size.y - split.thickness);
                split.innerPosition = split.borderPosition - vec2(0, split.thickness);
                split.size = vec2(size.x, split.thickness);
                break;

            case RegionAlign.bottom:
                split.borderPosition = absolutePosition;
                split.innerPosition = split.borderPosition + vec2(0, split.thickness);
                split.size = vec2(size.x, split.thickness);
                break;

            case RegionAlign.left:
                split.borderPosition = absolutePosition + vec2(size.x - split.thickness, 0);
                split.innerPosition = split.borderPosition - vec2(split.thickness, 0);
                split.size = vec2(split.thickness, size.y);
                break;

            case RegionAlign.right:
                split.borderPosition = absolutePosition;
                split.innerPosition = split.borderPosition + vec2(split.thickness, 0);
                split.size = vec2(split.thickness, size.y);
                break;

            default:
                return;
        }
    }

    void renderSplit() {
        if (!resizable && !showSplit)
            return;

        renderer.renderColorQuad(splitBorderRenderObject, splitColors[spliteState(false)],
                                 split.borderPosition, split.size);
        renderer.renderColorQuad(splitInnerRenderObject, splitColors[spliteState(true)],
                                 split.innerPosition, split.size);
    }

    void renderVerticalScroll() {
        if (!verticalScrollButton.visible)
            return;

        with (verticalScrollButton) {
            const vec2 buttonOffset = vec2(this.size.x-regionOffset.right,
                                           scrollController.buttonOffset);
            renderer.renderVerticalChain(buttonRenderObjects, state,
                                         absolutePosition + buttonOffset,
                                         scrollController.buttonSize);
        }
    }

    void renderHorizontalScroll() {
        if (!horizontalScrollButton.visible)
            return;

        with (horizontalScrollButton) {
            const vec2 buttonOffset = vec2(scrollController.buttonOffset,
                                           this.size.y - regionOffset.bottom);
            renderer.renderHorizontalChain(buttonRenderObjects, state,
                                           absolutePosition + buttonOffset,
                                           scrollController.buttonSize);
        }
    }

    void pollHorizontalScroll() {
        if (!horizontalScrollButton.visible)
            return;

        if (enteredSplitsCount > 0) {
            horizontalScrollButton.isEnter = false;
            return;
        }

        with (horizontalScrollButton) {
            const vec2 buttonOffset = vec2(scrollController.buttonOffset,
                                           this.size.y - regionOffset.bottom);
            const Rect rect = Rect(absolutePosition + buttonOffset,
                                   vec2(scrollController.buttonSize, regionOffset.bottom));
            isEnter = pointInRect(app.mousePos, rect);

            scrollController.buttonMaxOffset = size.x - regionOffset.right;
            scrollController.buttonMaxSize = size.x - scrollController.buttonMinSize;

            if (isClick)
                scrollController.pollButton();
        }
    }

    void pollVerticalScroll() {
        if (!verticalScrollButton.visible)
            return;

        if (enteredSplitsCount > 0) {
            verticalScrollButton.isEnter = false;
            return;
        }

        with (verticalScrollButton) {
            const vec2 buttonOffset = vec2(this.size.x-regionOffset.right,
                                           scrollController.buttonOffset);
            const Rect rect = Rect(absolutePosition + buttonOffset,
                                   vec2(regionOffset.right, scrollController.buttonSize));
            isEnter = pointInRect(app.mousePos, rect);

            scrollController.buttonMaxOffset = size.y - regionOffset.bottom;
            scrollController.buttonMaxSize = size.y - scrollController.buttonMinSize;

            if (isClick)
                scrollController.pollButton();
        }
    }

    void scrollToWidget() {
    }
}
