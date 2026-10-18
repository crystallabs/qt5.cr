# QT_DISABLE_DEPRECATED_BEFORE must match the parser flags in `qt.yml`.  Qt is
# built with RTTI, which the `#to?` downcasts of the wrappers need.
CXXFLAGS := -std=c++17 -DQT_DISABLE_DEPRECATED_BEFORE=0x050F00 -Wall -Wno-unused-function -fPIC -I$(QT_INCLUDE_DIR) -I.
CPPFILES := qt_binding_$(BINDING_PLATFORM).cpp
OBJFILES := $(CPPFILES:.cpp=.o)
LIBFILE  := binding_$(BINDING_PLATFORM).a

AR ?= ar
RM ?= rm

all: $(LIBFILE)

clean:
	$(RM) -f $(OBJFILES)
	$(RM) -f $(LIBFILE)

$(LIBFILE): $(OBJFILES)
	$(AR) rcs $@ $^

%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c -o $@ $<

.PHONY: clean
