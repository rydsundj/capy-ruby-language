class Node
  attr_accessor :value

  @@inside_if = false
  @@functions = {}
  @@currentScope = [{}]
  @@returnedCalled = false
  @@returnValue = ""

  def self.inside_if
    @@inside_if
  end

  def self.current_scope
    @@currentScope.last
  end
end

class VarExist < Node
  def initialize(name)
    @name = name
  end

  def execute
    # Start variable lookup from the top of the scope stack
    @@currentScope.reverse_each do |scope_hash|
      return scope_hash[@name] if scope_hash.key?(@name)
    end
    # If variable is not found, raise an error
    abort("Variable '#{@name}' is not defined. Aborting program.")
  end
end

class AtomNode < Node
  def initialize(value)
    @value = value
  end

  def execute
    @value
  end
end

class Var < Node
  attr_accessor :name

  def initialize(name, value = 'Default')
    @name = name
    @value = value
  end

  def execute
    VarExist.new(@name).execute
  end
end

class Print < Node
  def initialize(value)
    @value = value
  end

  def execute
    if @value.execute.class == Array
      print "["
      @value.execute.each do |e|
        print e.execute
        if e != @value.execute.last
          print ", "
        end
      end
      print "]"
      puts
    else
      puts @value.execute
    end
  end
end

class Define < Node
  attr_accessor :name, :expr

  def initialize(name, expr)
    @name = name.execute
    @expr = expr
  end

  def execute
    if expr.class == Var
      @@currentScope.last[@name] = VarExist.new(@expr.name).execute
    else
      @@currentScope.last[@name] = @expr.execute
    end
  end
end

class Assign < Node
  attr_accessor :name, :expr

  def initialize(name, expr)
    @name = name.execute
    @expr = expr
  end

  def execute
    if VarExist.new(@name).execute
      if expr.class == Var
        @@currentScope.last[@name] = VarExist.new(@expr.name).execute
      else
        @@currentScope.last[@name] = @expr.execute
      end
    end
  end
end

class Or < Node
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def execute
    @value = @left.execute || @right.execute
  end
end

class And < Node
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def execute
    @value = @left.execute && @right.execute
  end
end

class Not < Node
  attr_accessor :expr

  def initialize(expr)
    @expr = expr
  end

  def execute
    @value = !@expr.execute
  end
end

class AddNode < Node
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def execute
    @value = @left.execute + @right.execute
  end

end

class SubNode < Node
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def execute
    @value = @left.execute - @right.execute
  end

end


class MultNode < Node
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def execute
    @value = @left.execute * @right.execute
  end

end

class DivNode < Node
  attr_accessor :left, :right

  def initialize(left, right)
    @left = left
    @right = right
  end

  def execute
    @value = @left.execute / @right.execute
  end

end

class ComparisonNode < Node
  attr_accessor :left, :op, :right

  def initialize(left, op, right)
    @left = left
    @op = op
    @right = right
  end

  def execute
    case @op
    when '<'
      @left.execute < @right.execute
    when '>'
      @left.execute > @right.execute
    when '<='
      @left.execute <= @right.execute
    when '>='
      @left.execute >= @right.execute
    when '=='
      @left.execute == @right.execute
    when '!='
      @left.execute != @right.execute
    end
  end
end

class ElseNode < Node
  attr_accessor :statements

  def initialize(statements)
    @statements = statements
  end

  def execute
    if @@inside_if
      @@inside_if = false
      @statements.each(&:execute)
    end
  end
end

class ElseifNode < Node
  attr_accessor :condition, :statements

  def initialize(condition, statements)
    @condition = condition
    @statements = statements
  end

  def execute
    if @@inside_if && @condition.execute
      @@inside_if = false
      @statements.each(&:execute)
    end
  end
end

class IfNode < Node
  attr_accessor :condition, :statements

  def initialize(condition, statements)
    @condition = condition
    @statements = statements
  end

  def execute
    if @condition.execute
      @statements.each(&:execute)
    else
      @@inside_if = true
    end
  end
end

class StopNode < Node
  def execute
    @@inside_if = false
  end
end

class WhileNode < Node
  attr_accessor :condition, :statements

  def initialize(condition, statements)
    @condition = condition
    @statements = statements
  end

  def execute
    while @condition.execute
      @statements.each(&:execute)
    end
  end
end

class ForNode < Node
  attr_accessor :number, :statements

  def initialize(number, statements)
    @number = number.execute
    @statements = statements
  end

  def execute
    if @number < 1
      abort("Integer in for-loop must be greater than 0.")
    end
    for _ in 1..@number
      @statements.each(&:execute)
    end
  end
end


class FuncNode < Node
  attr_accessor :identifier, :parameters, :statements

  def initialize(identifier, parameters, statements)
    @identifier = identifier
    @parameters = parameters
    @statements = statements
  end

  def execute
    if not @@functions.has_key?(@identifier)
      @@functions[@identifier.execute] = self
    else
      abort("Function #{@identifier} already exists")
    end
  end
end

class FuncCallNode < Node
  attr_accessor :identifier, :arguments

  def initialize(identifier, arguments)
    @identifier = identifier
    @arguments = arguments
  end

  def execute
    if @@functions.has_key?(@identifier.execute)
      func_node = @@functions[@identifier.execute]
      params = func_node.parameters
      if params.length != @arguments.length
        abort("Number of arguments doesn't match the function definition for #{@identifier}")
      end

      # Create a new scope for the function call
      new_scope = {}

      # Assign the arguments to the parameter names in the new scope
      params.each_with_index do |param, index|
        new_scope[param.name] = @arguments[index].execute
      end

      @@currentScope.push(new_scope)

      # Execute the function's statements with the new scope
      func_node.statements.each do |statement|
        if @@returnedCalled
          break
        end

        statement.execute

        if statement.class == ReturnNode
          break
        end
      end

      # Restore the old scope
      @@currentScope.pop

      if @@returnedCalled
        @@returnedCalled = false
        return @@returnValue
      end

    else
      abort("Function #{@identifier} is not defined")
    end
  end
end

class ReturnNode < Node

  def initialize(value)
    @value = value
  end

  def execute
    @@returnValue = @value.execute
    @@returnedCalled = true
  end
end

class AddListNode < Node
  attr_accessor :array, :element

  def initialize(array, element)
    @array = array
    @element = element
  end

  def execute
    arrayObject = VarExist.new(@array.execute).execute

    # Ensure that the arrayObject is actually an array
    unless arrayObject.is_a?(Array)
      abort("'#{@array.execute}' must be an array.")
    end

    arrayObject << @element

    arrayObject
  end
end

class RemoveLastNode < Node
  attr_accessor :array

  def initialize(array)
    @array = array
  end

  def execute
    arrayObject = VarExist.new(@array.execute).execute

    # Ensure that the arrayObject is actually an array
    unless arrayObject.is_a?(Array)
      abort("removelast function can only be used on arrays.")
    end

    if arrayObject.size != 0
      return arrayObject.pop.execute
    else
      abort("Can not removelast on empty array '#{@array.execute}'.")
    end
  end
end

class IndexNode < Node
  attr_accessor :array, :index

  def initialize(array, index)
    @array = array
    @index = index.execute
  end

  def execute
    # Make sure that the index is a non-negative integer
    unless index.is_a?(Integer) && index >= 0
      abort("Index must be a non-negative integer.")
    end

    # Get the list from the current scope
    arrayObject = VarExist.new(@array.execute).execute

    # Make sure that the list is actually an array
    unless arrayObject.is_a?(Array)
      abort("Variable '#{@array.execute}' must be an array.")
    end

    # Make sure that the index is within the bounds of the list
    unless index < arrayObject.length
      abort("Index is larger than length of '#{@array.execute}'.")
    end

    # Return the value at the specified index
    arrayObject[index].execute
  end
end
