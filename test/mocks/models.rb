class MyModel
  
  #normally this would be provided by active record:
  def self.table_name
    "my_models"
  end
  
  attr_accessor :name, :age, :calorie_intake, :auspicious_fortune, :birth_month
  
  def self.field_defs
    @@my_field_definitions ||= FieldDefs.new(MyModel) do
      
      field(:name)
      
      field(:age).display_proc do |age|
        "#{age} years old"
      end
      
      field(:calorie_intake).human_name("% Daily value USDA recommended intake")
      
      field(:auspicious_fortune).label(:personality_trait)
      
      field(:zodiac_sign).label(:personality_trait).reader_proc do |my_model|
        if(my_model.birth_month == 1 || my_model.birth_month == 2)
          "possibly Aquarius"
        else
          "not Aquarius"      
        end
      end.writer_proc do |my_model, value_to_write|
        if(value_to_write == "possibly Aquarius")
          my_model.birth_month = 2
        else
          my_model.birth_month = 6
        end
      end
      
    end     
  end
  
end