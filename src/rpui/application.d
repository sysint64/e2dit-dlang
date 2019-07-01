module rpui.application;

import std.conv;
import std.array;
import std.string;

import derelict.sdl2.image;
import derelict.sdl2.sdl;
import derelict.sdl2.ttf;

import gapi.opengl;
import rpui.events;
import rpui.events_observer;
import rpui.input;
import rpui.cursor;
import rpui.primitives;

abstract class Application {
    EventsObserver events = new EventsObserver();
    CursorManager cursorManager = new CursorManager();

    struct WindowData {
        SDL_Window* window;
        SDL_GLContext glContext;
        int viewportWidth = 1024;
        int viewportHeight = 768;
    }

    struct Times {
        float current = 0f;
        float delta = 0f;
        float last = 0f;
        immutable part = 1_000.0 / 60.0;
    }

    protected WindowData windowData;
    private Times times;
    private bool isSDLInit = false;

    final void run() {
        loadShared();
        initSDL();
        initGL();
        onCreate(CreateEvent());
        mainLoop();
    }

    ~this() {
        if (isSDLInit) {
            stopSDL();
        }
    }

    void onRender() {
    }

    void onCreate(in CreateEvent event) {
    }

    void onDestroy() {
    }

    void onProgress(in ProgressEvent event) {
    }

    void onWindowResize(in WindowResizeEvent event) {
    }

    private void loadShared() {
        DerelictGL3.load();
        DerelictSDL2.load();
        DerelictSDL2Image.load();
        DerelictSDL2TTF.load();
    }

    private void initSDL() {
        if (SDL_Init(SDL_INIT_VIDEO) < 0)
            throw new Error("Failed to init SDL");

        if (TTF_Init() < 0)
            throw new Error("Failed to init SDL TTF");

        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
        SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
        SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
        SDL_GL_SetSwapInterval(2);

        windowData.window = SDL_CreateWindow(
            "Simple data oriented GAPI",
            SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,
            windowData.viewportWidth,
            windowData.viewportHeight,
            SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE
        );

        if (windowData.window == null)
            throw new Error("SDL Error: " ~ to!string(SDL_GetError()));

        windowData.glContext = SDL_GL_CreateContext(windowData.window);

        if (windowData.glContext == null)
            throw new Error("SDL Error: " ~ to!string(SDL_GetError()));

        SDL_GL_SwapWindow(windowData.window);
        DerelictGL3.reload();

        isSDLInit = true;
    }

    private void stopSDL() {
        SDL_GL_DeleteContext(windowData.glContext);
        SDL_DestroyWindow(windowData.window);
        SDL_Quit();
        TTF_Quit();
    }

    private void initGL() {
        glDisable(GL_CULL_FACE);
        glDisable(GL_MULTISAMPLE);
        glDisable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glClearColor(150.0f/255.0f, 150.0f/255.0f, 150.0f/255.0f, 0);
    }

    private void mainLoop() {
        bool running = true;

        void render() {
            if (times.current >= times.last + times.part) {
                times.delta = (times.current - times.last) / 1000.0f;
                onProgress(ProgressEvent(times.delta));
                times.last = times.current;
                glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
                onRender();
                SDL_GL_SwapWindow(windowData.window);
            }
        }

        while (running) {
            times.current = SDL_GetTicks();
            SDL_Event event;

            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT) {
                    running = false;
                }

                if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
                    const width = event.window.data1;
                    const height = event.window.data2;

                    glViewport(0, 0, width, height);

                    windowData.viewportWidth = width;
                    windowData.viewportHeight = height;

                    onWindowResize(WindowResizeEvent(width, height));
                    events.notify(WindowResizeEvent(width, height));

                    // SDL_GL_MakeCurrent(windowData.window, windowData.glContext);
                    // render();
                }

                if (event.type == SDL_MOUSEMOTION) {
                    const button = createMouseButtonFromSdlState(event.motion.state);
                    events.notify(MouseMoveEvent(event.motion.x, event.motion.y, button));
                }

                if (event.type == SDL_MOUSEBUTTONDOWN) {
                    const button = createMouseButtonFromButtonSdlEvent(event);
                    events.notify(MouseDownEvent(event.button.x, event.button.y, button));

                    switch (event.button.clicks) {
                        case 2:
                            events.notify(DblClickEvent(event.button.x, event.button.y, button));
                            break;

                        case 3:
                            events.notify(TripleClickEvent(event.button.x, event.button.y, button));
                            break;

                        default:
                            // Ignore
                    }
                }

                if (event.type == SDL_MOUSEBUTTONUP) {
                    const button = createMouseButtonFromButtonSdlEvent(event);
                    events.notify(MouseUpEvent(event.button.x, event.button.y, button));
                }

                if (event.type == SDL_MOUSEWHEEL) {
                    events.notify(MouseWheelEvent(event.wheel.x, event.wheel.y));
                }

                if (event.type == SDL_TEXTINPUT) {
                    const ch = fromStringz(dtext(event.text.text[0..4]).ptr)[0];
                    events.notify(TextEnteredEvent(ch));
                }

                if (event.type == SDL_KEYDOWN) {
                    try {
                        const key = to!(KeyCode)(to!(int)(event.key.keysym.sym));
                        setKeyPressed(key, true);
                        events.notify(KeyPressedEvent(key));
                    } catch (Exception e) {
                    }
                }

                if (event.type == SDL_KEYUP) {
                    try {
                        const key = to!(KeyCode)(to!(int)(event.key.keysym.sym));
                        setKeyPressed(key, false);
                        events.notify(KeyReleasedEvent(key));
                    } catch (Exception e) {
                    }
                }
            }

            render();
        }
    }

    private void handleEvents(in SDL_Event event) {
    }
}
