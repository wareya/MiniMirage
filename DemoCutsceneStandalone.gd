extends Reference

func demo_cutscene(cutscene : CutsceneInstance):
    var bg_texture = load("res://minimirage/art/test_bg.jpg")
    
    var tachie_a = load("res://minimirage/art/tachie/vn engine test tachie base.png")
    var tachie_b = load("res://minimirage/art/tachie/vn engine test tachie confident.png")
    var tachie_c = load("res://minimirage/art/tachie/vn engine test tachie really.png")
    
    var face_a = load("res://minimirage/art/tachie/vn engine test face base.png")
    var face_b = load("res://minimirage/art/tachie/vn engine test face confident.png")
    var face_c = load("res://minimirage/art/tachie/vn engine test face really.png")
    
    var bg_image = cutscene.add_background(bg_texture)
    
    print("showing bg")
    cutscene.image_show(bg_image)
    yield(bg_image, "transition_finished")
    print("and it's done")
    
    cutscene.set_text("Something approaches.")
    yield(cutscene, "cutscene_continue")
    
    cutscene.set_nametag("???")
    
    cutscene.set_text("Wow! What is that?")
    yield(cutscene, "cutscene_continue")
    
    cutscene.clear_text()
    cutscene.set_nametag("Guide")
    
    var image = cutscene.add_tachie(tachie_a)
    cutscene.adv_set_face(face_a)
    cutscene.image_set_position(image, Vector2(-0.5, 0.0))
    
    cutscene.image_show(image)
    yield(image, "transition_finished")
    
    cutscene.set_text("Wait, it's not...? It can't be!")
    yield(cutscene, "cutscene_continue")
    
    cutscene.clear_text()
    cutscene.image_set_texture(image, tachie_b)
    cutscene.image_set_scale(image, Vector2(-1.2, 1.2))
    cutscene.adv_set_face(face_b)
    
    cutscene.image_smooth_position(image, Vector2(0.0, 0.0))
    yield(image, "transition_finished")
    
    cutscene.set_text("Oh my god, why didn't you tell me about this!")
    yield(cutscene, "cutscene_continue")
    
    cutscene.textbox_set_chat(Vector2(0.05, -0.4))
    
    cutscene.set_text("This... This is good.")
    yield(cutscene, "cutscene_continue")
    
    cutscene.image_set_texture(image, tachie_c)
    cutscene.adv_set_face(face_c)
    
    cutscene.set_text("But you know--this isn't all there is to life.")
    yield(cutscene, "cutscene_continue")
    
    cutscene.clear_text()
    
    cutscene.textbox_hide()
    yield(cutscene, "textbox_transition_finished")
    
    cutscene.image_set_texture(image, tachie_a)
    cutscene.adv_set_face(face_a)
    
    cutscene.image_smooth_scale(image, Vector2(-1.0, 1.0))
    yield(image, "transition_finished")
    
    cutscene.image_smooth_position(image, Vector2(0.3, 0.0))
    yield(image, "transition_finished")
    
    cutscene.image_set_scale(image, Vector2(1.0, 1.0))
    cutscene.textbox_set_chat(Vector2(0.15, -0.35), "upright")
    
    cutscene.set_text("You need to stop and smell the roses. Listen to the music. Help out a friend or two. That kind of thing.")
    yield(cutscene, "cutscene_continue")
    
    cutscene.textbox_hide()
    yield(cutscene, "textbox_transition_finished")
    
    cutscene.image_hide(image)
    yield(image, "transition_finished")
    
    cutscene.textbox_set_chat(Vector2(0.5, 0.3), "downright")
    cutscene.chat_set_face(face_a)
    
    cutscene.set_text("I'll be off, now!")
    yield(cutscene, "cutscene_continue")
    
    cutscene.chat_set_face(face_b, true)
    
    cutscene.set_text("Take care!")
    yield(cutscene, "cutscene_continue")
    
    # Always call this at the end of the cutscene.
    cutscene.finish()
