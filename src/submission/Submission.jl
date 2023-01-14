""" 
Specifies where to submit a task.
"""
abstract type Submission end 

""" 
Flag to ask to run a function within the 
current process. 
"""
struct ThisProcess <: Submission end 