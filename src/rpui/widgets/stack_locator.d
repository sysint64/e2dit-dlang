module rpui.widgets.stack_locator;

import std.math;

import rpui.widget;
import rpui.primitives;
import rpui.math;

package struct StackLocator {
    Widget holder;
    Orientation orientation = Orientation.vertical;

    private vec2 maxSize = vec2(0, 0);
    private vec2 lastWidgetPosition = vec2(0, 0);
    private Widget lastWidgetInStack = null;

    void attach(Widget widget) {
        holder = widget;
        holder.widthType = Widget.SizeType.wrapContent;
        holder.heightType = Widget.SizeType.wrapContent;
        setDecorator();
    }

    private void setDecorator() {
        holder.children.decorateWidgets(delegate(Widget widget) {
            Widget cell = new Widget();
            cell.associatedWidget = widget;
            cell.skipFocus = true;
            return cell;
        });
    }

    void updateWidgetsPosition() {
        with (holder) {
            lastWidgetPosition = vec2(0, 0);

            foreach (Widget cell; children) {
                lastWidgetInStack = cell.firstWidget;

                if (orientation == Orientation.vertical) {
                    cell.widthType = SizeType.matchParent;
                    cell.size.y = lastWidgetInStack.outerSize.y;
                    cell.position.y = lastWidgetPosition.y;
                    cell.updateSize();
                } else {
                    cell.size.x = lastWidgetInStack.outerSize.x;
                    cell.heightType = SizeType.matchParent;
                    cell.position.x = lastWidgetPosition.x;
                    cell.updateSize();
                }

                lastWidgetPosition += lastWidgetInStack.size + lastWidgetInStack.outerOffsetEnd;
                maxSize = vec2(
                    fmax(maxSize.x, lastWidgetInStack.outerSize.x),
                    fmax(maxSize.y, lastWidgetInStack.outerSize.y),
                );

                cell.locator.updateAbsolutePosition();  // TODO: Maybe it's deprecated
            }
        }
    }

    void updateSize() {
        with (holder) {
            if (orientation == Orientation.vertical) {
                if (widthType == SizeType.wrapContent) {
                    size.x = maxSize.x > parent.innerSize.x ? maxSize.x : parent.innerSize.x;
                }

                if (heightType == SizeType.wrapContent) {
                    if (lastWidgetInStack !is null) {
                        size.y = lastWidgetPosition.y + lastWidgetInStack.outerOffset.bottom + innerOffsetSize.y;
                    }
                }
            }

            if (orientation == Orientation.horizontal) {
                if (heightType == SizeType.wrapContent) {
                    size.y = maxSize.y > innerSize.y ? maxSize.y : innerSize.y;
                }

                if (widthType == SizeType.wrapContent) {
                    if (lastWidgetInStack !is null) {
                        size.x = lastWidgetPosition.x + lastWidgetInStack.outerOffset.right + innerOffsetSize.x;
                    }
                }
            }
        }
    }
}