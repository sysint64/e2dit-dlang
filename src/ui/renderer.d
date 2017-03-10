module ui.renderer;

import std.conv;
import std.math;
import gapi;
import math.linalg;

import application;
import ui.render_objects;
import ui.manager;


class Renderer {
    this(Manager manager) {
        createShaders();
        this.manager = manager;
        app = Application.getInstance();
    }

    vec2 toScreenPosition(in vec2 position, in vec2 size) {
        return vec2(position.x, app.windowHeight - size.y - position.y);
    }

    void renderQuad(BaseRenderObject renderObject, in string state,
                    in vec2 position, in vec2 size)
    {
        p_texAtlasShader.bind();

        renderObject.position = toScreenPosition(position, size);
        renderObject.scaling = size;

        with (renderObject.texCoordinates[state]) {
            p_texAtlasShader.setUniformMatrix("MVP", renderObject.lastMVPMatrix);
            p_texAtlasShader.setUniformTexture("texture", manager.theme.skin);
            p_texAtlasShader.setUniformVec2f("texOffset", normOffset);
            p_texAtlasShader.setUniformVec2f("texSize", normSize);
            p_texAtlasShader.setUniformFloat("alpha", 1.0f);
        }

        renderObject.render(camera);
    }

    void renderHorizontalChain(BaseRenderObject[string] renderObjects, in string state,
                               in vec2 position, in float size)
    {
        const float height = renderObjects["center"].texCoordinates[state].size.y;
        renderHorizontalChain(renderObjects, state, position, vec2(size, height));
    }

    void renderHorizontalChain(BaseRenderObject[string] renderObjects, in string state,
                               in vec2 position, in vec2 size)
    {
        p_texAtlasShader.bind();

        const float leftWidth = renderObjects["left"].texCoordinates[state].size.x;
        const float rightWidth = renderObjects["right"].texCoordinates[state].size.x;
        const float centerWidth = size.x - leftWidth - rightWidth;

        const vec2 leftPos = position;
        const vec2 centerPos = leftPos + vec2(leftWidth, 0);
        const vec2 rightPos = centerPos + vec2(centerWidth, 0);

        renderQuad(renderObjects["left"], state, leftPos, vec2(leftWidth, size.y));
        renderQuad(renderObjects["center"], state, centerPos, vec2(centerWidth, size.y));
        renderQuad(renderObjects["right"], state, rightPos, vec2(rightWidth, size.y));
    }

    void renderVerticalChain(BaseRenderObject[string] renderObjects, in string state,
                             in vec2 position, in float size)
    {
        const float width = renderObjects["middle"].texCoordinates[state].size.x;
        renderVerticalChain(renderObjects, state, position, vec2(width, size));
    }

    void renderVerticalChain(BaseRenderObject[string] renderObjects, in string state,
                             in vec2 position, in vec2 size)
    {
        p_texAtlasShader.bind();

        const float topHeight = renderObjects["top"].texCoordinates[state].size.y;
        const float bottomHeight = renderObjects["bottom"].texCoordinates[state].size.y;
        const float middleHeight = size.y - topHeight - bottomHeight;

        const vec2 topPos = position;
        const vec2 middlePos = topPos + vec2(0, topHeight);
        const vec2 bottomPos = middlePos + vec2(0, middleHeight);

        renderQuad(renderObjects["top"], state, topPos, vec2(size.x, topHeight));
        renderQuad(renderObjects["middle"], state, middlePos, vec2(size.x, middleHeight));
        renderQuad(renderObjects["bottom"], state, bottomPos, vec2(size.x, bottomHeight));
    }

    void renderText(TextRenderObject text, in string state, in vec2 position, in vec2 size) {
        const vec2 textPos = position + text.offsets[state];
        text.color = text.colors[state];
        text.scaling = vec2(size);
        text.position = toScreenPosition(textPos, vec2(size));
        text.render(camera);
    }

    void renderColorQuad(BaseRenderObject renderObject, in vec4 color,
                         in vec2 position, in vec2 size)
    {
        p_colorShader.bind();

        renderObject.position = toScreenPosition(position, size);
        renderObject.scaling = size;

        p_colorShader.setUniformMatrix("MVP", renderObject.lastMVPMatrix);
        p_colorShader.setUniformVec4f("color", color);

        renderObject.render(camera);
    }

    @property Camera camera() { return p_camera; }
    @property void camera(Camera val) { p_camera = val; }
    @property Shader texAtlasShader() { return p_texAtlasShader; }
    @property Shader maskTexAtlasShader() { return p_maskTexAtlasShader; }
    @property Shader colorShader() { return p_colorShader; }

private:
    Shader p_texAtlasShader;
    Shader p_maskTexAtlasShader;
    Shader p_colorShader;
    Camera p_camera;

    Manager manager;
    Application app;

    void createShaders() {
        p_texAtlasShader = Shader.createFromFile("tex_atlas.glsl");
        p_maskTexAtlasShader = Shader.createFromFile("mask_tex_atlas.glsl");
        p_colorShader = Shader.createFromFile("color.glsl");
    }
}