module e2ml.exception;


class E2TMLException : Exception {
    this() { super(""); }
    this(in string details) { super(details); }
}


class NotFoundException : E2TMLException {
    this() { super("not found"); }
    this(in string details) { super(details); }
}


class NotObjectException : E2TMLException {
    this() { super("it is not an object"); }
    this(in string details) { super(details); }
    static @property string typeName() { return "e2tml.node.ObjectNode"; }
}


class NotParameterException : E2TMLException {
    this() { super("it is not a parameter"); }
    this(in string details) { super(details); }
    static @property string typeName() { return "e2tml.node.Parameter"; }
}


class NotValueException : E2TMLException {
    this() { super("it is not a value"); }
    this(in string details) { super(details); }
    static @property string typeName() { return "e2tml.value.Value"; }
}


class NotParameterOrValueException : E2TMLException {
    this() { super("it is not a parameter or value"); }
    this(in string details) { super(details); }
}


class NotNumberValueException : E2TMLException {
    this() { super("it is not a number value"); }
    this(in string details) { super(details); }
    static @property string typeName() { return "e2tml.value.NumberValue"; }
}


class NotBooleanValueException : E2TMLException {
    this() { super("it is not a number value"); }
    this(in string details) { super(details); }
    static @property string typeName() { return "e2tml.value.BooleanValue"; }
}


class NotStringValueException : E2TMLException {
    this() { super("it is not a string value"); }
    this(in string details) { super(details); }
    static @property string typeName() { return "e2tml.value.StringValue"; }
}


class NotArrayValueException : E2TMLException {
    this() { super("it is not an array value"); }
    this(in string details) { super(details); }
    static @property string typeName() { return "e2tml.value.ArrayValue"; }
}


class WrongNodeType : E2TMLException {
    this() { super("wrong type of value"); }
    this(in string details) { super(details); }
}