module rpui.rpdl_widget_factory;

import std.path;
import std.meta;
import std.traits : hasUDA, getUDAs, isFunction, ParameterDefaults, Unqual;
import std.container.array;

import rpdl;
import rpdl.node;
import rpui.basic_rpdl_exts;
import rpui.gapi_rpdl_exts;

import gapi.texture;

import rpui.math;
import rpui.basic_types;
import rpui.traits;
import rpui.widget;
import rpui.view;

import rpui.widgets.button;

/// Factory for construction view from rpdl layout data.
final class RpdlWidgetFactory {
    /// Root view widget - container for other widgets.
    @property Widget rootWidget() { return rootWidget_; }
    private Widget rootWidget_;

    private RpdlTree layoutData;
    private View view;

    this(View view, in string fileName) {
        layoutData = new RpdlTree(dirName(fileName));
        layoutData.load(baseName(fileName), RpdlTree.FileType.text);
        debug layoutData.save(baseName(fileName ~ ".bin"), RpdlTree.FileType.bin);
        this.view = view;
    }

    /**
     * This is a main method of factory - it will create and insert widgets
     * by reading the children of `widgetNode`, if `widgetNode` is null
     * then reading will be from layout root node.
     */
    void createWidgets(Node widgetNode = null) {
        if (widgetNode is null) {
            widgetNode = layoutData.root;
        }

        foreach (Node childNode; widgetNode.children) {
            if (auto objectNode = cast(ObjectNode) childNode) {
                auto widget = createWidgetFromNode(objectNode);
                // readVisibleRules(widget, objectNode);
                widget.onPostCreate();
            } else {
                throw new Error("Failed to create widget");
            }
        }
    }

    /// Create widget depends of `widgetNode.name` and insert to `parentWidget`.
    Widget createWidgetFromNode(ObjectNode widgetNode, Widget parentWidget = null) {
        switch (widgetNode.name) {
            case "Button":
                return createWidget!Button(widgetNode, parentWidget);

            default:
                throw new Error("Unspecified widget type " ~ widgetNode.name);
        }
    }

    /**
     * Create widget from `widgetNode` data and insert it to `parentWidget`.
     * If `parentWidget` is null then insert to `uiManager` root view widget.
     */
    Widget createWidget(T : Widget)(ObjectNode widgetNode, Widget parentWidget = null) {
        T widget = new T();
        readFields!T(widget, widgetNode);

        if (parentWidget !is null) {
            parentWidget.children.addWidget(widget);
        } else {
            rootWidget_ = view.rootWidget;
            view.addWidget(widget);
        }

        // Create children widgets
        foreach (Node childNode; widgetNode.children) {
            if (auto objectNode = cast(ObjectNode) childNode) {
                Widget newWidget = createWidgetFromNode(objectNode, widget);
                readVisibleRules(newWidget, objectNode);
                newWidget.onPostCreate();
            }
        }

        return widget;
    }

    // Tell the system how to interprete types of fields in widgets
    // and how to extract them
    // first argumen is name of type
    // second is accessor in RpdlTree
    // third is selector - additional path to find value
    private enum name = 0;
    private enum accessor = 1;
    private enum selector = 2;

    private enum typesMap = AliasSeq!(
        ["bool", "optBoolean", ".0"],
        ["int", "optInteger", ".0"],
        ["float", "optNumber", ".0"],
        ["string", "optString", ".0"],
        ["dstring", "optUTF32String", ".0"],

        ["vec2", "optVec2f", ""],
        ["vec3", "optVec3f", ""],
        ["vec4", "optVec4f", ""],
        ["vec2i", "optVec2i", ""],
        ["vec3i", "optVec3i", ""],
        ["vec4i", "optVec4i", ""],
        ["vec2ui", "optVec2ui", ""],
        ["vec3ui", "optVec3ui", ""],
        ["vec4ui", "optVec4ui", ""],

        ["Texture2DCoords", "optTexCoord", ""],
        ["Rect", "optRect", ""],
        ["FrameRect", "optFrameRect", ""],
        ["IntRect", "optIntRect", ""],
    );

    /**
     * Finds all fields in widget with @`rpui.widget.Widget.field` attribute
     * and fill widget members with values from rpdl file.
     */
    void readFields(T : Widget)(T widget, ObjectNode widgetNode) {
        foreach (symbolName; getSymbolsNamesByUDA!(T, Widget.field)) {
            auto defaultValue = mixin("widget." ~ symbolName);
            alias SymbolType = typeof(defaultValue);

            static if (is(SymbolType == Array!CT, CT)) {
            }
            else {
                readField!(T, SymbolType, symbolName)(widget, widgetNode, defaultValue);
            }
        }
    }

    private void readField(T : Widget, SymbolType, string symbolName)
        (T widget, Node widgetNode, SymbolType defaultValue = SymbolType.init)
    {
        bool foundType = false;

        foreach (type; typesMap) {
            mixin("alias RawType = " ~ type[name] ~ ";");

            static if (is(SymbolType == RawType)) {
                foundType = true;
                const fullSymbolPath = symbolName ~ type[selector];
                enum call = "widgetNode." ~ type[accessor] ~ "(fullSymbolPath, defaultValue)";
                const value = mixin(call);

                // assign value to widget field
                // TODO:
                // static if (type[name] == "dstring") {
                    // mixin("widget." ~ symbolName ~ " = uiManager.stringsRes.parseString(value);");
                // } else {
                    mixin("widget." ~ symbolName ~ " = value;");
                // }

                break;
            }
        }
    }

    private void readVisibleRules(Widget widget, ObjectNode widgetNode) {
        const rule = widgetNode.optString("tabVisibleRule.0", null);

        // TODO:
        // if (rule !is null ) {
        //     auto dependWidget = cast(TabButton) rootWidget.resolver.findWidgetByName(rule);

        //     if (dependWidget !is null) {
        //         widget.visibleRules.insert(() => dependWidget.checked);
        //     }
        // }
    }
}
