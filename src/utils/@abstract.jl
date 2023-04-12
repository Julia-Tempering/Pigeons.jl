"""
    my_fct() = @abstract()

Define an abstract function (i.e. which gives an error message if calling it 
is attempted). 
"""
macro abstract() quote error("Attempted to call an abstract function.") end end