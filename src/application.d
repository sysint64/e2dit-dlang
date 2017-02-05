module application;

import std.stdio;
import std.conv;
import std.path;
import std.file : thisExePath;

import derelict.sfml2.system;
import derelict.sfml2.window;
import derelict.opengl3.gl;

import input;
import log;
import settings;
import editor.mapeditor : MapEditor;
import math.linalg;

import gapi.shader;
import gapi.camera;


abstract class Application {
    static Application getInstance() {
        return MapEditor.getInstance();
    }

    void initPath() {
        p_binDirectory = dirName(thisExePath());
        p_resourcesDirectory = buildPath(p_binDirectory, "res");
    }

    void run() {
        initPath();
        initSFML();
        initGL();
        log = new Log();
        scope(exit) sfWindow_destroy(window);

        p_settings = Settings.getInstance();
        settings.load(binDirectory, "settings.e2t");

        writeln(settings.theme);
        onCreate();
        loop();
    }

    void render() {}

    void logError(Char, T...)(in Char[] fmt, T args) {
        debug log.display(vec4(0.8f, 0.1f, 0.1f, 1), fmt, args);
    }

    void logWarning(Char, T...)(in Char[] fmt, T args) {
        debug log.display(vec4(0.1f, 0.1f, 0.8f, 1), fmt, args);
    }

    void logDebug(Char, T...)(in Char[] fmt, T args) {
        debug log.display(vec4(0.3f, 0.3f, 0.3f, 1), fmt, args);
    }

    void warning(Char, T...)(in Char[] fmt, T args) {

    }

    void error(Char, T...)(in Char[] fmt, T args) {

    }

    void criticalError(Char, T...)(in Char[] fmt, T args) {
        logError(fmt, args);
    }

    // Events
    void onCreate() {}

    void onPostRender(Camera camera) {
        log.render(camera);
    }

    void onPreRender(Camera camera) {}

    void onKeyPressed(in KeyCode key) {}
    void onKeyReleased(in KeyCode key) {}
    void onTextEntered(in utfchar key) {}

    void onMouseDown(in uint x, in uint y, in MouseButton button) {
        p_mouseButton = button;
    }

    void onMouseUp(in uint x, in uint y, in MouseButton button) {
        p_mouseButton = MouseButton.mouseNone;
    }

    void onDblClick(in uint x, in uint y, in MouseButton button) {}
    void onMouseMove(in uint x, in uint y) {}
    void onMouseWheel(in uint dx, in uint dy) {}

    void onResize(in uint width, in uint height) {
        p_windowWidth = width;
        p_windowHeight = height;
    }

    @property string binDirectory() { return p_binDirectory; }
    @property string resourcesDirectory() { return p_resourcesDirectory; }
    @property Settings settings() { return p_settings; }

    @property uint screenWidth() { return p_screenWidth; }
    @property uint screenHeight() { return p_screenHeight; }
    @property uint windowWidth() { return p_windowWidth; }
    @property uint windowHeight() { return p_windowHeight; }
    @property uint viewportWidth() { return p_windowWidth; }
    @property uint viewportHeight() { return p_windowHeight; }


    @property vec2i mousePos() { return p_mousePos; }
    @property vec2i mouseClickPos() { return p_mouseClickPos; }
    @property uint mouseButton() { return p_mouseButton; }

    @property Shader lastShader() { return p_lastShader; }
    @property void lastShader(Shader shader) { p_lastShader = shader; }
    @property float deltaTime() { return p_deltaTime; }
    @property float currentTime() { return p_currentTime; }

private:
    string p_binDirectory;
    string p_resourcesDirectory;
    sfWindow* window;
    Log log;

    Settings p_settings;

    // GAPI
    Shader p_lastShader = null;

    // Video
    uint p_screenWidth;
    uint p_screenHeight;
    uint p_windowWidth;
    uint p_windowHeight;

    // Cursor
    vec2i p_mousePos;
    vec2i p_mouseClickPos;
    uint p_mouseButton = MouseButton.mouseNone;

    // Time
    float p_deltaTime;
    float p_currentTime;
    float lastTime = 0;
    sfClock *clock;

    void initSFML() {
        sfVideoMode desktomVideoMode = sfVideoMode_getDesktopMode();
        // TODO: uncomment, in my linux this return garbage
        // p_screenWidth  = desktomVideoMode.width;
        // p_screenHeight = desktomVideoMode.height;
        p_screenWidth = 9999;
        p_screenHeight = 9999;

        p_windowWidth  = 1024;
        p_windowHeight = 768;

        sfContextSettings settings;

        with (settings) {
            depthBits = 24;
            stencilBits = 8;
            antialiasingLevel = 0;
            majorVersion = 2;
            minorVersion = 1;
        }

        sfVideoMode videoMode = {windowWidth, windowHeight, 24};

        const(char)* title = "E2DIT";
        window = sfWindow_create(videoMode, title, sfDefaultStyle, &settings);
        sfWindow_setVerticalSyncEnabled(window, false);
        sfWindow_setFramerateLimit(window, 60);

        DerelictGL.reload();
        clock = sfClock_create();
    }

    void initGL() {
        glDisable(GL_CULL_FACE);
        glDisable(GL_MULTISAMPLE);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glClearColor(150.0f/255.0f, 150.0f/255.0f, 150.0f/255.0f, 0);
    }

    void calculateTime() {
        sfTime time = sfClock_getElapsedTime(clock);
        p_currentTime = time.microseconds;
        p_deltaTime = (p_currentTime - lastTime) * 0.001f;
        lastTime = p_currentTime;
    }

    void loop() {
        bool running = true;

        while (running) {
            auto mousePos = sfMouse_getPosition(window);
            p_mousePos = vec2i(mousePos.x, mousePos.y);

            sfEvent event;

            while (sfWindow_pollEvent(window, &event)) {
                if (event.type == sfEvtClosed)
                    running = false;
                else
                    handleEvents(event);
            }

            calculateTime();
            sfWindow_setActive(window, true);

            glViewport(0, 0, viewportWidth, viewportHeight);
            glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
            render();
            glFlush();
            sfWindow_display(window);
        }
    }

    void handleEvents(in sfEvent event) {
        switch (event.type) {
            case sfEvtResized:
                onResize(event.size.width, event.size.height);
                break;

            case sfEvtTextEntered:
                onTextEntered(event.text.unicode);
                break;

            case sfEvtKeyPressed:
                onKeyPressed(to!KeyCode(event.key.code));
                break;

            case sfEvtKeyReleased:
                onKeyReleased(to!KeyCode(event.key.code));
                break;

            case sfEvtMouseButtonPressed:
                with (event.mouseButton)
                    onMouseDown(x, y, to!MouseButton(button));

                break;

            case sfEvtMouseButtonReleased:
                with (event.mouseButton)
                    onMouseUp(x, y, to!MouseButton(button));

                break;

            case sfEvtMouseMoved:
                onMouseMove(event.mouseMove.x, event.mouseMove.y);
                break;

            case sfEvtMouseWheelScrolled:
                const uint delta = to!uint(event.mouseWheelScroll.delta);

                switch (event.mouseWheelScroll.wheel) {
                    case sfMouseVerticalWheel:
                        onMouseWheel(0, delta);
                        break;

                    case sfMouseHorizontalWheel:
                        onMouseWheel(delta, 0);
                        break;

                    default:
                        break;
                }

                break;

            default:
                break;
        }
    }
}
