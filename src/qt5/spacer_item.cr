module Qt
  class SpacerItem
    # Creates a new spacer expanding (by default) horizontally only, taking up
    # any space left in a `Layout`.
    def self.horizontal(policy = SizePolicy::Policy::Expanding)
      new(1, 1, h_data: policy)
    end

    # Creates a new spacer expanding (by default) vertically only, taking up
    # any space left in a `Layout`.
    def self.vertical(policy = SizePolicy::Policy::Expanding)
      new(1, 1, v_data: policy)
    end
  end
end
