# frozen_string_literal: true

# Single table inheritance subclass of User. It exists so that the test suite
# covers the version lookup for a class that PaperTrail stores under the name of
# its base class.
class Admin < User
end
