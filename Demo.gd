extends Control


func _ready():
    yield(Engine.get_main_loop(), "idle_frame")
    yield(Engine.get_main_loop(), "idle_frame")
    
    # start cutscene (it loops)
    start_cutscene()

func start_cutscene():
    print("Starting cutscene...")
    
    var cutscene = CutsceneStarter.load_and_start_cutscene("res://DemoCutsceneStandalone.gd", "demo_cutscene")
    yield(cutscene, "cutscene_finished")
    
    print("Cutscene finished!")
    
    # start cutscene over
    yield(get_tree().create_timer(1.0), "timeout")
    call_deferred("start_cutscene")
