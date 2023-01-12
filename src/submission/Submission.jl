""" 
Specifies how to run a job.
"""
abstract type Submission end 

""" 
Flag to ask to run a function within the 
current process. 
"""
struct InCurrentProcess <: Submission end 




