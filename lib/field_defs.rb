require 'rubygems'
require 'active_support'

# An instance of FiledDefs contains a collection of FieldDefs::Field objects
# each of which defines things about a particular field.
#
# Individual FieldDefs::Field objects can be retrieved by name via field_called
#
# Once you have a FieldDefs::Field you can retrieve things like: 
# * FieldDefs::Field.display_proc -- used for formating a value for to the end user, sometimes including html
# * FieldDefs::Field.reader_proc -- used to retrieve a value for the given field from it's entity
# * FieldDefs::Field.writer_proc -- used to set a value for the given field into it's entity
# * FieldDefs::Field.human_name -- used as the name of this field for end-user display\
#
# To define field defs for a particular entity, pass a block to FieldDefs.new
#
# like so:
#
#   defs = FieldDefs.new(User) do
#     field(:name)
#   end
#
# This will provide default implementations for the field :name
# so now when I want to set name of user, I can do:
#
#   defs.field_called(:name).writer_proc.call(user, "Bob")
#
# to read the users name:
#
#   name = defs.field_called(:name).reader_proc.call(user)
#
# to read the users name, and format it for display:
#
#   name_field = defs.field_called(:name)
#   name_to_display = name_field.display_proc.call(name_field.reader_proc.call(user))
#
# For more complicated fields, We can chain together the various modifications being made to the field :name so as to make the logic about that field exist in one chunk of code
#
#      field(:name).reader_proc do |user|
#        user.related_entity.name
#      end.writer_proc do |user, name|
#        user.related_entity.name = name
#      end.human_name("Name")
#
class FieldDefs  
  class << self
    def define_in_module(&block)
      block.binding.eval("self").class_eval do
        (class << self; self end).send(:define_method, :included) do |base|
          base.class_eval do
            cattr_accessor :field_defs_defining_block
            def self.field_defs
              @@field_definitions ||= FieldDefs.new(self, &self.field_defs_defining_block)
            end
          end
          base.field_defs_defining_block = block
        end
      end
    end
  end
  
  # Representation of a single field within the context of a set of FieldDefs
  #
  # Intantiated via calls to FieldDefs.field in the context of a FieldDefs initialize block
  #
  class Field
    attr_reader :field_name, :for_model
    # arguments: symbol name of the field, FieldDefs parent object
    def initialize(field_name, defs) #:nodoc:
      @field_name = field_name
      @for_model = defs.for_model
    end
    
    #used for applying labels to fields, you can then find all fields with a given lable by using FieldDefs.all_attributes_labeled
    def label(label_name)
      @labels ||= []
      @labels << label_name.to_sym
      self
    end
    #returns true/false based on if this field has the label asked for
    def has_label?(label_name)
      (@labels || []).include?(label_name.to_sym)
    end

    # give me a block that describes how to display a potential value for the named field.
    #
    # If you call me without a block, I will return either the last block you sent me, or the default display_proc.
    #
    # Block should take 1 arg (being the value to format) and return the value, formatted.
    # default proc just runs to_s on the value.
    def display_proc(&block)
      #defined by default_for_proc_type in initialize!
    end
    # give me a block that describes how to retrieve the value for the named field from a given entity
    #
    # If you call me wthout a block, I will return either the last block you send me, or the default reader_proc
    #
    # Block should take 1 arg (being the entity) and return the value retrieved
    # default proc just assumes there is a method with the same name as field_name on the entity
    def reader_proc(&block)
      #defined by default_for_proc_type in initialize!
    end
    # give me a block that describes how to set the value for the named field for the given entity
    #
    # If you call me without a block, I will reeturn either the last block you sent me, or the default writer_proc
    #
    # Block should take 2 args (1st the entity, 2nd the value to be written)
    # default proc assumes there is an = method with the same name as field_name on the entity
    def writer_proc(&block)
      #defined by default_for_proc_type in initialize!
    end
    # give me an arg and I will set a string for how the name of this field should be seen to end users
    #
    # call me with no args and I will give you the human_name you gave me
    def human_name(*args)
      #defined by default_for_arg_type in initialize!
    end
  end
  
  # Call me with a block in which you define all the fields that I define
  #
  # Example:
  #
  #   FieldDefs.new(User) do
  #     field(:name).human_name("Name")
  #     field(:birthday).human_name("Birthday").display_proc do |val|
  #       val.strftime("%a %b %d %Y")
  #     end
  #     field(:related_groups).human_name("Names of Groups belonged To").reader_proc do |obj|
  #       obj.groups.collect{ |g| g.name }
  #     end
  #   end
  #  
  def initialize(for_model, &block)
    @fields = {}
    @for_model = for_model
    @field_class = Class.new(Field)
    self.class.setup_defaults(self)
    self.instance_eval(&block)
  end
  
  #recursive proc for the setting-up of defaults
  #each call to global_defaults sets setup proc to execute the default and then call the previous setup proc
  cattr_accessor :setup_proc #:nodoc:
  
  #Setup default types (display_proc, writer_proc etc...) called by initialize
  def self.setup_defaults(for_new_field_defs) #:nodoc:
    for_new_field_defs.instance_eval do
      default_for_proc_type(:display_proc) do |field_defs|
        lambda { |object| 
          if object.is_a?(Numeric) or object.is_a?(Time) or object.is_a?(Date)
            object
          else
            object.to_s
          end
        }
      end
      default_for_proc_type(:writer_proc) do |field_defs|
        lambda{ |object, value| object.send("#{field_defs.field_name}=", value) }
      end
      default_for_proc_type(:reader_proc) do |field_defs|
        lambda{ |object| object.send("#{field_defs.field_name}") }
      end
    
      default_for_arg_type(:human_name) do |field_defs|
        field_defs.field_name.to_s.humanize.capitalize
      end
    end
    if(self.setup_proc)
      self.setup_proc.call(for_new_field_defs)
    end
  end
  
  # Call me with a block in which you define defaults for new types of things available to FieldDef definitions
  #
  # Example:
  #   FieldDefs.global_defaults do
  #       default_for_arg_type(:order_sql) do |field_defs|
  #         "#{field_defs.for_model.table_name}.#{field_defs.field_name.to_s}"
  #       end
  #   end  
  #
  # Plugins that make use of field_defs typically make calls to global_defaults in their init methods
  # to setup new kinds of things on field_defs
  # The above example adds the order_sql arg type as an available thing on all FieldDefs
  def self.global_defaults(&block)
    original_setup = self.setup_proc || Proc.new{}
    self.setup_proc = Proc.new do |for_new_field_defs|
      original_setup.call(for_new_field_defs)
      for_new_field_defs.instance_eval(&block)
    end
  end
  
  #the model passed to initialize, for which these are fields for.
  attr_reader :for_model
  
  # Call this within the context of global_defaults to define a new type of thing on all FieldDefs
  #
  # Call within the context of FieldDefs initialize block to define a new type of thing just within the context of that block
  # 
  # This type of thing can then be called to get a proc, or called with :arg to get a value
  # 
  # Example 
  #
  #  FieldDefs.new(User) do
  #
  #     # define a default mixed_type for 'spanglish'
  #     default_for_mixed_type(:spanglish) do |field_defs|
  #       [Translator.translate(field_defs.field_name),
  #       Proc.new do |value|
  #         value
  #       end]
  #     end
  #
  #     # define the spanglish mixed_type for the name field
  #     field(:name).spanglish("Nombre") do |val|
  #       "#{val.to_s}o"
  #     end
  #
  #  end
  # ...
  #     >> puts field.name(:arg)
  #     "Nombre"
  #     >> field.name.call(user.name)
  #     "Bobo"
  # 
  def default_for_mixed_type(field_type, &block)
    field_block_name = "#{field_type.to_s}_block"
    unless @field_class.respond_to?(field_block_name)
      @field_class.class_eval do
        cattr_accessor field_block_name.to_sym
        eval %Q{
          def #{field_type}(*args_here, &block_here)
            if block_given?
              @#{field_type}_args = args_here[0]
              @#{field_type} = lambda(&block_here)
              self
            else
              if(args_here[0] == :arg)
                @#{field_type}_args || #{field_block_name}.call(self).first
              else
                @#{field_type} || #{field_block_name}.call(self).last
              end
            end
          end        
        }
      end
    end
    @field_class.send("#{field_block_name}=", block)
  end

  # Call this within the context of global_defaults to define a new type of thing on all FieldDefs
  #
  # Call within the context of FieldDefs initialize block to define a new type of thing just within the context of that block
  # 
  # This type of thing can then be called to get a single value
  #
  # Example:
  # 
  #   FieldDefs.new(User) do
  # 
  #     # define a default arg_type for 'order_sql'
  #     default_for_arg_type(:order_sql) do |field_defs|
  #       "#{field_defs.for_model.table_name}.#{field_defs.field_name.to_s}"
  #     end
  # 
  #     # define the order_sql for the group field
  #     field(:group_name).order_sql("groups.name")
  # 
  #   end
  # ...
  #     >> puts field_defs.field_called(:name).order_sql
  #     "users.name"
  #     >> puts field_defs.field_called(:group_name).order_sql
  #     "groups.name"
  # 
  # 
  def default_for_arg_type(field_type, &block)
    field_block_name = "#{field_type.to_s}_block"
    unless @field_class.respond_to?(field_block_name)
      @field_class.class_eval do
        cattr_accessor field_block_name.to_sym
        eval %Q{
          def #{field_type}(*args)
            if args.size > 0
              @#{field_type} = args[0]
              self
            else
              @#{field_type} || #{field_block_name}.call(self)
            end
          end        
        }
      end
    end
    @field_class.send("#{field_block_name}=", block)
  end
  
  # Call this within the context of global_defaults to define a new type of thing on all FieldDefs
  #
  # Call within the context of FieldDefs initialize block to define a new type of thing just within the context of that block
  # 
  # This type of thing can then be called to get a proc
  #
  # Example:
  #
  #   FieldDefs.new(User) do
  #
  #     default_for_proc_type(:changes) do |field_defs|
  #       Proc.new do |thing|
  #         thing.changes[field_defs.field_name.to_s]
  #       end
  #     end
  #
  #     field(:group_name).changes do |user|
  #       user.group.changes['name']
  #     end
  #
  #   end
  # ...
  #     >> user.changes
  #     => {"name"=>["Al", "Bob"], "foo"=>["bar", "baz"], ...}
  #     >> user.group.changes
  #     => {"name"=>[nil, "The Bobs"], ... }
  #     
  #     >> puts field_defs.field_called(:name).changes
  #     => ["Al", "Bob"]
  #     >> puts field_defs.field_called(:group_name).order_sql
  #     => [nil, "The Bobs"]
  #
  #  
  def default_for_proc_type(field_type, &block)
    field_block_name = "#{field_type.to_s}_block"
    unless @field_class.respond_to?(field_block_name)
      @field_class.class_eval do
        cattr_accessor field_block_name.to_sym
        eval %Q{
          def #{field_type}(&block_here)
            if block_given?
              @#{field_type} = lambda(&block_here)
              self
            else
              @#{field_type} || #{field_block_name}.call(self)
            end
          end        
        }
      end
    end
    @field_class.send("#{field_block_name}=", block)
  end
  
  # Convenience method for chaining FieldDefs::Field.display_proc and FieldDefs::Field.reader_proc as intended
  #
  # i.e. instead of:
  #     field = field_defs.field_called(:name)
  #     field.display_proc.call(field.reader_proc.call(user))
  # you can do:
  #     field_defs.display_for(user, :name)
  #
  def display_for(object, field_name)
    fdef = field_called(field_name)
    fdef.display_proc.call(fdef.reader_proc.call(object))
  end
  
  # Create a new FieldDefs::Field, 
  # Save in in this FieldDefs instance by the given field_name, 
  # And return it for further modification
  #
  # This is how you define fields within the context of a FieldDefs initialize block
  #
  # Example:
  # 
  #  FieldDefs.new(MyModel) do
  # 
  #     field(:name)
  #
  #     field(:age).display_proc do |age|
  #       "#{age} years old"
  #     end
  #
  #     field(:calorie_intake).human_name("% Daily value USDA recommended intake")
  #  
  #  end
  #
  def field(field_name, &block)
    @fields[field_name.to_sym] = @field_class.new(field_name.to_sym, self)
    if block_given?
      @fields[field_name.to_sym].instance_eval(&block)
    end
    @fields[field_name.to_sym]
  end
  
  # Get a hash of all fields of the form: field name => human name
  def all_attributes
    @@all_attributes ||= 
      begin
        to_return = {}
        @fields.each do |key, field|
          to_return[key] = field.human_name
        end
        to_return
      end
  end
  
  # Get a hash of all fields of the form: field name => human name
  #
  # Include only those fields that have the given label
  def all_attributes_labeled(label_name)
    to_return = {}
    @fields.each do |key, field|
      if field.has_label?(label_name.to_sym)
        to_return[key] = field.human_name
      end
    end
    to_return
  end
  
  # Get an array of all fields thate have the given label
  def all_fields_labeled(label_name)
    @fields.values.reject do |field|
      !field.has_label?(label_name.to_sym)
    end
  end
  
  # Get an array of all fields defined on this FieldDefs
  def all_fields
    @fields.values
  end
  
  #find a field by it's name
  def field_called(field_name)
    return nil if field_name.to_s.empty?
    # return nil if field_name.to_s.empty?
    @fields[field_name.to_sym]
  end
  
  # Get an array of fields based on the given array of field names
  def fields_called(field_names)
    field_names.collect{ |name| field_called(name) || (raise ArgumentError, "field called #{name} not found") }
  end
  
end