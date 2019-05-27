module rpui.widgets.button;

import std.container.array;

import rpui.math;
import rpui.basic_types;
import rpui.widget;
import rpui.view;
import rpui.events;
import rpui.widgets.button.measure;
import rpui.widgets.button.render;

class Button : Widget {
    @field bool allowCheck = false;
    @field Align textAlign = Align.center;
    @field VerticalAlign textVerticalAlign = VerticalAlign.middle;
    @field Array!string icons;
    @field utf32string caption = "Button";

    private string iconsGroup;
    package Measure measure;
    private RenderData renderData;
    private RenderTransforms renderTransforms;

    this(in string style = "Button", in string iconsGroup = "icons") {
        super(style);

        this.drawChildren = false;
        this.iconsGroup = iconsGroup;

        // TODO: rm hardcode
        size = vec2(50, 21);
        widthType = SizeType.wrapContent;
    }

    override void onProgress(in ProgressEvent event) {
        locator.updateLocationAlign();
        locator.updateVerticalLocationAlign();
        locator.updateAbsolutePosition();
        locator.updateRegionAlign();
        updateSize();

        updateRenderTransforms(this, &renderTransforms, &renderData, &view.theme);
    }

    override void onRender() {
        render(this, view.theme, renderData, renderTransforms);
    }

    override void updateSize() {
        super.updateSize();

        if (widthType == SizeType.wrapContent) {
            if (!icons.empty) {
                size.x = measure.iconsAreaSize + measure.iconGaps + measure.iconOffsets.x * 2;
            } else {
                size.x = measure.textLeftMargin + measure.textRightMargin;
            }

            if (measure.textWidth != 0f) {
                size.x += measure.textWidth;

                if (!icons.empty) {
                    size.x += measure.textLeftMargin;
                }
            }
        }
    }

    protected override void onCreate() {
        super.onCreate();
        measure = readMeasure(view.theme.tree.data, style);
        renderData = readRenderData(view.theme, style);
    }
}