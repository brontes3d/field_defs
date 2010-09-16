require 'test/unit'
require 'rubygems'
require "#{File.dirname(__FILE__)}/../init"
require File.expand_path(File.dirname(__FILE__) + '/mocks/models.rb')

class FieldDefsTest < Test::Unit::TestCase

  def setup
    @field_defs = MyModel.field_defs
    @model_me = MyModel.new
      @model_me.name = "Jacob"
      @model_me.age = 24
      @model_me.calorie_intake = 3000
      @model_me.birth_month = 10
      @model_me.auspicious_fortune = "Seek truth and justice in better abstractions"
    @model_you = MyModel.new
      @model_you.name = "Unknown"
      @model_you.age = (5..200)
      @model_you.calorie_intake = (50..5000)
      @model_you.birth_month = 1
      @model_you.auspicious_fortune = "Read the test cases and all will be revealed"
  end
  
  #test retrieval of this from defined field defs
  def test_field_called
    field = @field_defs.field_called(:age)
    assert field.is_a?(FieldDefs::Field)
  end
  
  #test retrieval of this from defined field defs
  def test_all_attributes_labeled
    fields = @field_defs.all_attributes_labeled(:personality_trait)
    
    assert_equal(['auspicious_fortune', 'zodiac_sign'], 
                fields.keys.collect(&:to_s).sort)
  end

  def test_all_fields_labeled
    all_fields_labeled = @field_defs.all_fields_labeled(:personality_trait)
    
    fields_called =  @field_defs.fields_called([:auspicious_fortune, :zodiac_sign])
    
    sorter = Proc.new{ |a,b| a.field_name.to_s <=> b.field_name.to_s }
    
    assert_equal(fields_called.sort(&sorter), all_fields_labeled.sort(&sorter))
  end
  
  #test retrieval of this from defined field defs
  def test_all_attributes
    assert_equal(
      { :name => "Name", 
        :age => "Age", 
        :calorie_intake => "% Daily value USDA recommended intake", 
        :auspicious_fortune => "Auspicious fortune", 
        :zodiac_sign => "Zodiac sign"
      },
      @field_defs.all_attributes
    )
  end
  
  #retrieve a specific field def and test both default and overridden:
  def test_human_name
    assert_equal("Name", @field_defs.field_called(:name).human_name)
    assert_equal("% Daily value USDA recommended intake", @field_defs.field_called(:calorie_intake).human_name)
  end
  
  def test_display_proc
    assert_equal("5 years old", @field_defs.field_called(:age).display_proc.call(5))    
    assert_equal("Hi", @field_defs.field_called(:name).display_proc.call("Hi"))    
  end

  def test_writer_proc
    @field_defs.field_called(:age).writer_proc.call(@model_me, 5)
    assert_equal(5, @model_me.age)

    @field_defs.field_called(:zodiac_sign).writer_proc.call(@model_me, "not Aquarius")
    assert_equal(6, @model_me.birth_month)
  end
  
  def test_reader_proc
    assert_equal(24, @field_defs.field_called(:age).reader_proc.call(@model_me))
    
    assert_equal("not Aquarius", @field_defs.field_called(:zodiac_sign).reader_proc.call(@model_me))    
  end
  
  def test_has_label
    assert !@field_defs.field_called(:age).has_label?(:personality_trait)

    assert @field_defs.field_called(:zodiac_sign).has_label?(:personality_trait)
  end
  
  def test_order_sql
    FieldDefs.global_defaults do
        default_for_arg_type(:order_sql) do |field_defs|
          "#{field_defs.for_model.table_name}.#{field_defs.field_name.to_s}"
        end
    end
    
    new_defs = FieldDefs.new(MyModel) do
      field(:age)
      field(:zodiac_sign).order_sql("my_models.birth_month")
    end
  
    assert_equal("my_models.age", new_defs.field_called(:age).order_sql)

    assert_equal("my_models.birth_month", new_defs.field_called(:zodiac_sign).order_sql)
  end
  
  def test_mixed_type
    new_defs = FieldDefs.new(MyModel) do
      
      default_for_mixed_type(:mixything) do |field_defs|
        ["extra arg in default", 
        Proc.new do |mymod|
          "Hi mixy"
        end]
      end
      
      field(:name)
      field(:auspicious_fortune).mixything("I mixed it") do |mymod|
        mymod
      end
      
    end
    
    assert_equal("extra arg in default", new_defs.field_called(:name).mixything(:arg))
    assert_equal("Hi mixy", new_defs.field_called(:name).mixything.call(@model_you))

    assert_equal("I mixed it", new_defs.field_called(:auspicious_fortune).mixything(:arg))
    assert_equal(@model_you, new_defs.field_called(:auspicious_fortune).mixything.call(@model_you))
  end
  
  def test_new_things_on_field_defs
    
    new_defs = FieldDefs.new(MyModel) do
      
      default_for_proc_type(:anagram) do |field_defs|
        Proc.new do |mymod|
          "Hi"          
        end
      end

      default_for_proc_type(:gobbledyGoo) do |field_defs|
        Proc.new do |mymod|
          "Arrrr"
        end
      end
      
      default_for_proc_type(:anagram) do |field_defs|
        Proc.new do |mymod|
          source_str = mymod.send(field_defs.field_name).to_s
          charfirst = source_str[0,1]
          charlast = source_str[-1,1]
          to_return = source_str.dup
          to_return[0,1] = charlast
          to_return[-1,1] = charfirst
          to_return
        end
      end
      
      
      field(:auspicious_fortune)
      field(:name).anagram do |mymod|
        "Something else!"
      end
      
    end
    
    # puts new_defs.field_called(:name).class
    # puts new_defs.field_called(:name).class.superclass
    # puts new_defs.field_called(:name).class.superclass.superclass
    # 
    # puts new_defs.field_called(:name).anagram.call(@model_you)
    new_defs.field_called(:name).anagram.call(@model_you)
    # 
    # puts new_defs.field_called(:auspicious_fortune).anagram.call(@model_you)
    new_defs.field_called(:auspicious_fortune).anagram.call(@model_you)
    
    
  end
  

end
