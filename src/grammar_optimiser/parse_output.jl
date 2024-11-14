using JSON

function read_json(json_file)
    """
    Reads a JSON file and returns the parsed content.
    # Arguments
    - `json_file::String`: the path to the JSON file
    # Result
    - `json_parsed::Dict`: the parsed JSON content
    """
    json_content = read(json_file, String)
    json_parsed = JSON.parse(json_content)

    witnesses = json_parsed["Call"][1]["Witnesses"]
    last_witness = witnesses[end]
    last_value = last_witness["Value"] #The best solution found
    return last_value
end
