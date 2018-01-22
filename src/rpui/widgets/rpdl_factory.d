/**
 * Creating add insering widgets from rpdl file.
 *
 * Copyright: © 2017 RedGoosePaws
 * License: Subject to the terms of the MIT license, as written in the included LICENSE.txt file.
 * Authors: Andrey Kabylin
 */

module rpui.widgets.rpdl_factory;

import traits;

import rpdl;
import rpdl.node;
import basic_rpdl_extensions;

import std.path;
import std.stdio;
import std.typecons: tuple;
import std.meta;
import std.traits : hasUDA, getUDAs, isFunction, ParameterDefaults, Unqual;
import std.container.array;

import math.linalg;
import basic_types;
import rpui.widget;
import rpui.view.attributes;
import rpui.manager;
import rpui.rpdl_extensions;

import gapi.texture;

import rpui.cursor;
import rpui.widget;
import rpui.widgets.panel;
import rpui.widgets.button;
import rpui.widgets.stack_layout;
import rpui.widgets.checkbox;
import rpui.widgets.label;
import rpui.widgets.multiline_label;
import rpui.widgets.tree_list;

/// Factory for construction view from rpdl layout data.
class RPDLWidgetFactory {
    /// Root view widget - container for other widgets.
    @property Widget rootWidget() { return p_rootWidget; }

    /// Create factory for UI manager and for layout placed in `fileName`.
    this(Manager uiManager, in string fileName) {
        layoutData = new RPDLTree(dirName(fileName));
        layoutData.load(baseName(fileName), RPDLTree.IOType.text);
        debug layoutData.save(baseName(fileName ~ ".bin"), RPDLTree.IOType.bin);
        this.uiManager = uiManager;
    }

    /// Create factory for UI manager.
    this(Manager uiManager) {
        this.uiManager = uiManager;
    }

    /// Create factory with loading rpdl file from compile time.
    static RPDLWidgetFactory createStatic(string fileName)(Manager uiManager) {
        RPDLWidgetFactory factory = RPDLWidgetFactory(uiManager);
        layoutData = new RPDLTree(dirName(fileName));
        layoutData.staticLoad!(baseName(fileName))();
        return factory;
    }

    /// Create widget depends of `widgetNode.name` and insert to `parentWidget`.
    Widget createWidgetFromNode(ObjectNode widgetNode, Widget parentWidget = null) {
        switch (widgetNode.name) {
            case "StackLayout":
                return createWidget!StackLayout(widgetNode, parentWidget);

            case "Panel":
                return createWidget!Panel(widgetNode, parentWidget);

            case "Button":
                return createWidget!Button(widgetNode, parentWidget);

            case "Checkbox":
                return createWidget!Checkbox(widgetNode, parentWidget);

            case "Label":
                return createWidget!Label(widgetNode, parentWidget);

            case "MultilineLabel":
                return createWidget!MultilineLabel(widgetNode, parentWidget);

            case "TreeList":
                return createWidget!TreeList(widgetNode, parentWidget);

            case "TreeListNode":
                return createWidget!TreeListNode(widgetNode, parentWidget);

            default:
                return null;
        }
    }

    /**
     * This is a main method of factory - it will create and insert widgets
     * by reading the children of `widgetNode`, if `widgetNode` is null
     * then reading will be from layout root node.
     */
    void createWidgets(Node widgetNode = null) {
        if (widgetNode is null)
            widgetNode = layoutData.root;

        foreach (Node childNode; widgetNode.children) {
            if (auto objectNode = cast(ObjectNode) childNode) {
                createWidgetFromNode(objectNode);
            } else {
                // TODO: throw an exception
            }
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
            parentWidget.addWidget(widget);
        } else {
            p_rootWidget = uiManager.rootWidget;
            uiManager.addWidget(widget);
        }

        // Create children widgets
        foreach (Node childNode; widgetNode.children) {
            if (auto objectNode = cast(ObjectNode) childNode) {
                createWidgetFromNode(objectNode, widget);
            }
        }

        return widget;
    }

    // Tell the system how to interprete types of fields in widgets
    // and how to extract them
    // first argumen is name of type
    // second is accessor in RPDLTree
    // third is selector - additional path to find value
    private enum name = 0;
    private enum accessor = 1;
    private enum selector = 2;

    private enum typesMap = AliasSeq!(
        ["bool", "optBoolean", ".0"],
        ["int", "optInteger", ".0"],
        ["float", "optNumber", ".0"],
        ["string", "optString", ".0"],
        ["dstring", "optUTFString", ".0"],

        ["vec2", "optVec2f", ""],
        ["vec3", "optVec3f", ""],
        ["vec4", "optVec4f", ""],
        ["vec2i", "optVec2i", ""],
        ["vec3i", "optVec3i", ""],
        ["vec4i", "optVec4i", ""],
        ["vec2ui", "optVec2ui", ""],
        ["vec3ui", "optVec3ui", ""],
        ["vec4ui", "optVec4ui", ""],

        ["Texture.Coord", "optTexCoord", ""],
        ["Align", "optAlign", ".0"],
        ["VerticalAlign", "optVerticalAlign", ".0"],
        ["Orientation", "optOrientation", ".0"],
        ["RegionAlign", "optRegionAlign", ".0"],
        ["Rect", "optRect", ""],
        ["FrameRect", "optFrameRect", ""],
        ["IntRect", "optIntRect", ""],

        ["Cursor.Icon", "optCursorIcon", ".0"],
        ["Panel.Background", "optPanelBackground", ".0"],
        ["Widget.SizeType", "optWidgetSizeType", ".0"],
    );

    /**
     * Finds all fields in widget with @`rpui.widget.Widget.Field` attribute
     * and fill widget members with values from rpdl file.
     */
    void readFields(T : Widget)(T widget, ObjectNode widgetNode) {
        foreach (symbolName; getSymbolsNamesByUDA!(T, Widget.Field)) {
            auto defaultValue = mixin("widget." ~ symbolName);
            alias SymbolType = typeof(defaultValue);

            static if (is(SymbolType == Array!CT, CT)) {
                auto array = widgetNode.getNode(symbolName);

                if (array is null)
                    continue;

                foreach (node; array.children) {
                    readArrayField!(T, CT, symbolName)(widget, widgetNode, node.name);
                }
            } else {
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
                static if (type[name] == "dstring") {
                    mixin("widget." ~ symbolName ~ " = uiManager.stringsRes.parseString(value);");
                } else {
                    mixin("widget." ~ symbolName ~ " = value;");
                }

                break;
            }
        }

        if (!foundType) {
            // Check if unsupported type is array
            static if (is(SymbolType == CT[], CT)) {
                auto array = widgetNode.getNode(symbolName);

                if (array is null)
                    return;

                foreach (node; array.children) {
                    readArrayField!(T, Unqual!CT, symbolName)(widget, widgetNode, node.name);
                }
            } else {
                assert(false, "type " ~ SymbolType.stringof ~ " doesn't allow");
            }
        }
    }

    private void readArrayField(T : Widget, SymbolType, string symbolName)
        (T widget, Node widgetNode, string nodeName)
    {
        const defaultValue = SymbolType.init;
        bool foundType = false;

        foreach (type; typesMap) {
            mixin("alias RawType = " ~ type[name] ~ ";");

            static if (is(SymbolType == RawType)) {
                foundType = true;
                const fullSymbolPath = symbolName ~ "." ~ nodeName;// ~ type[selector];
                enum call = "widgetNode." ~ type[accessor] ~ "(fullSymbolPath, defaultValue)";
                const value = mixin(call);

                // assign value to widget field
                static if (type[name] == "dstring") {
                    mixin("widget." ~ symbolName ~ " ~= uiManager.stringsRes.parseString(value);");
                } else {
                    mixin("widget." ~ symbolName ~ " ~= value;");
                }

                break;
            }
        }

        assert(foundType, "type " ~ SymbolType.stringof ~ " doesn't allow");
    }

private:
    RPDLTree layoutData;
    Manager uiManager;
    Widget p_rootWidget;
}
