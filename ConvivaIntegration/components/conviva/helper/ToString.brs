function toString(variable As dynamic) As string
    if type(variable) = "roInt" or type(variable) = "roInteger" or type(variable) = "roFloat" or type(variable) = "Float" then
        return str(variable).trim()
    else if type(variable) = "roBoolean" or type(variable) = "Boolean" then
        if variable = true then
            return "true"
        end if
        return "false"
    else If type(variable) = "roString" or type(variable) = "String" then
        return variable
    else
        return type(variable)
    end if
end function
