module rpui.widgets.button.render_system;

import std.container.array;

import rpui.widgets.button.widget;
import rpui.widgets.button.transforms_system;
import rpui.render.components_factory;
import rpui.render.components;
import rpui.render.renderer;
import rpui.theme;
import rpui.math;

import gapi.texture;

struct RenderData {
    StatefulChain background;
    Chain focusGlow;
    StatefulUiText captionText;
    Array!TexAtlasTextureQuad icons;
    bool textVisible = true;
}

final class ButtonRenderSystem : RenderSystem {
    private Button widget;
    private Theme theme;
    private RenderTransforms* transforms;
    private RenderData* renderData;

    this(Button widget, RenderData* renderData, RenderTransforms* transforms) {
        this.widget = widget;
        this.theme = widget.view.theme;
        this.transforms = transforms;
        this.renderData = renderData;
    }

    override void onRender() {
        renderData.background.state = widget.state;
        renderData.captionText.state = widget.state;

        // TODO: draw disabled
        const alpha = widget.isEnabled ? 1.0 : 0.5;

        renderHorizontalChain(
            theme,
            renderData.background,
            transforms.background,
            widget.partDraws,
            alpha
        );

        if (renderData.textVisible && widget.caption != "") {
            renderUiText(theme, renderData.captionText, transforms.captionText);
        }

        if (widget.focusable && widget.isFocused && widget.isEnabled) {
            renderHorizontalChain(
                theme,
                renderData.focusGlow,
                transforms.focusGlow,
                widget.partDraws
            );
        }

        renderIcons();
    }

    private void renderIcons() {
        for (int i = 0; i < widget.icons.length; ++i) {
            const iconTransforms = transforms.icons[i];
            const iconQuad = renderData.icons[i];

            renderTexAtlasQuad(theme, iconQuad, iconTransforms);
        }
    }
}
