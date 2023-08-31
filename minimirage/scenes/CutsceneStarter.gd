class_name CutsceneStarter

## Starts a cutscene function (from a script file) with a new CutsceneInstance
static func load_and_start_cutscene(filename : String, function_name : String):
    # create a CutsceneInstance to keep track of the cutscene and add it to the scene
    var cutscene = CutsceneInstance.new()
    Engine.get_main_loop().current_scene.add_child(cutscene)
    print("added cutsceneinstance to world")
    
    # load the object
    var script = load(filename).new()
    
    # put the object in the world if it's a Node, so that it doesn't leak memory
    # we make it a child of the CutsceneInstance so that it automatically cleans up
    if script is Node and !script.is_inside_tree():
        cutscene.add_child(script)
    
    # start the cutscene with the CutsceneInstance as its argument
    script.call(function_name, cutscene)
    
    return cutscene
    
    # on your end: wait for the cutscene to finish
    #yield(cutscene, "cutscene_finished")

## Starts a cutscene function (from an object) with a new CutsceneInstance
static func start_cutscene(script : Object, function_name : String):
    # create a CutsceneInstance to keep track of the cutscene and add it to the scene
    var cutscene = CutsceneInstance.new()
    Engine.get_main_loop().current_scene.add_child(cutscene)
    print("added cutsceneinstance to world 2")
    
    # start the cutscene with the CutsceneInstance as its argument
    script.call(function_name, cutscene)
    
    return cutscene
    
    # on your end: wait for the cutscene to finish
    #yield(cutscene, "cutscene_finished")
