module Qt
  class TabWidget
    # Adds a tab called *label* in the tab bar, using *widget* as content.
    #
    # Through this method, you can create a tab widget by writing:
    #
    # ```
    # tab_widget = Qt::TabWidget{
    #   "First"  => first_tab,
    #   "Second" => second_tab,
    # }
    # ```
    def []=(label : String, widget : Widget)
      add_tab(widget, label)
    end
  end
end
