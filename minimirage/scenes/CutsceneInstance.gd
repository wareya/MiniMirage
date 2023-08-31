extends CanvasLayer
class_name CutsceneInstance

# Custom input actions you can add:
# "cutscene_advance" - to advance text. pressing down on this also causes currently-running animations to be skipped.
#   common: m1, down arrow
# "cutscene_instant_text" - to make text instantly appear, but not advance. also doesn't skip animations.
#   common: on controllers, the "cancel" button. not needed if that button is bound to "ui_cancel".
# "cutscene_skip" - hold to skip animations, including the text type-in effect.
#   common: ctrl. PLEASE DO NOT PUT THIS ON ALT. PUTTING IT ON ALT MAKES IT HARD TO ALT TAB.

# Rate at which new characters are added to the textbox per second.
const typein_speed = 90.0
# Number of textboxes to skip per second when skipping.
# Note: skipping is slowed down by one frame per other animation (tachie/background transitions etc).
const skip_rate = 20.0
# Speed at which tachie (standing sprites) fade in. Higher values make them take less time. Reciprocal of seconds.
const tachie_fade_speed = 3.0
# Speed at which backgrounds fade in.
const bg_fade_speed = 1.5
# Speed at which the textbox fades in.
const textbox_fade_speed = 4.0
# Speed at which images move when smoothly moved. Reciprocal of seconds.
const tachie_move_speed = 4.0
# Speed at which images move when smoothly moved. Reciprocal of seconds.
const bg_move_speed = 0.5


# Used internally.
signal cutscene_continue

## Emitted when the cutscene is finished.
signal cutscene_finished

## Used to translate global world positions into the adjustment fractions used for positioning tachie and textboxes.
static func globalpos_to_screen_fraction(vec : Vector2):
    var viewport : Viewport = Engine.get_main_loop().get_root()
    var size =  viewport.get_visible_rect().size
    var xform = viewport.canvas_transform
    var local_vec = xform.xform(vec)
    var fraction_vec = (local_vec - size/2.0)/size.y*2.0
    return fraction_vec

## Call to check whether any cutscenes are currently running.
##
## For example, you can use this function to ignore input or pause the game when cutscenes are running.
static func cutscene_is_running():
    return Engine.get_main_loop().get_nodes_in_group("CutsceneInstance").size() > 0

## Sets the textbox and makes the cutscene instance start to type in the new text and wait for input.
##
## To wait for the cutscene instance to get input from the user, use the following wait command:
##
## `yield(instance, "cutscene_continue")`
func set_text(text : String):
    var label = current_textbox.get_node("Label")
    
    if current_textbox == chat_textbox:
        var size = estimate_good_chat_size(text)
        label.margin_left = _chat_textbox_alignment
        chat_portrait.visible = false
        
        if chat_portrait.texture:
            chat_portrait.visible = true
            label.margin_left += chat_portrait.rect_size.x + 16
            size.x += chat_portrait.rect_size.x + 16
            size.y = max(size.y, chat_portrait.rect_size.y)
        
        fix_chatbox_size(size)
    
    current_textbox.visible = true
    if current_textbox.modulate.a < 1.0:
        textbox_show()
    
    label.bbcode_enabled = true
    label.bbcode_text = text
    visible_characters = 0.0
    if should_skip_anims() or should_use_instant_text():
        visible_characters = -1
    label.visible_characters = int(visible_characters)

## Clears the textbox.
func clear_text():
    var label = current_textbox.get_node("Label")
    current_textbox.visible = true
    label.bbcode_enabled = true
    label.bbcode_text = ""
    label.visible_characters = -1

var images : Dictionary = {}

## Adds a tachie (standing sprite) to the scene, returning an image.
##
## Disclaimer: images are just TextureRects with special materials and signals attached.
func add_tachie(texture : Texture) -> TextureRect:
    var tr = TextureRect.new()
    tr.expand = true
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    tr.texture = texture
    tr.anchor_right = 1
    tr.anchor_bottom = 1
    tr.margin_right = 0
    tr.margin_bottom = 0
    add_child(tr)
    
    tr.material = preload("../shader/CutsceneImageMat.tres").duplicate()
    tr.material.set_shader_param("is_background", false)
    tr.material.set_shader_param("position", Vector2(0.0, 0.0))
    tr.material.set_shader_param("scale", Vector2(1.0, 1.0))
    tr.material.set_shader_param("rotation", 0.0)
    tr.material.set_shader_param("screen_size", dummy_control.rect_size)
    images[tr] = null
    tr.add_user_signal("transition_finished")
    
    return tr

## Adds a background to the scene, returning an image.
##
## Disclaimer: images are just TextureRects with special materials and signals attached.
func add_background(texture : Texture) -> TextureRect:
    var tr = add_tachie(texture)
    tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    tr.material.set_shader_param("is_background", true)
    VisualServer.canvas_item_set_z_index(tr.get_canvas_item(), -1)
    return tr

# Used internally.
static func image_smooth_param_vec2(tr : TextureRect, param : String, vec2 : Vector2, speed : float):
    var start_vec2 : Vector2 = tr.material.get_shader_param(param)
    
    yield(Engine.get_main_loop(), "idle_frame")
    if !is_instance_valid(tr):
        return
    
    var time_passed = 0.0
    while time_passed < 1.0:
        var delta = Engine.get_main_loop().current_scene.get_process_delta_time()
        time_passed = clamp(time_passed + delta * speed, 0.0, 1.0)
        if should_skip_anims(): time_passed = 1.0
        
        var real_vec2 = start_vec2.linear_interpolate(vec2, smoothstep(0.0, 1.0, time_passed))
        tr.material.set_shader_param(param, real_vec2)
        
        yield(Engine.get_main_loop(), "idle_frame")
        if !is_instance_valid(tr):
            return
    
    tr.emit_signal("transition_finished")

# Used internally.
static func image_is_bg(tr : TextureRect) -> bool:
    return tr.material.get_shader_param("is_background")

## Set the position for the given image.
##
## Positions are based on the height of the cutscene screen, with 1.0 representing
## the distance from the center of the screen to the top or bottom.
##
## So, a position of Vector2(1.0, 0.0) is only about half way towards the right side
## of a 16:9 screen.
##
## Applies instantly.
static func image_set_position(tr : TextureRect, pos : Vector2):
    tr.material.set_shader_param("position", pos)

## Set the position for the given image smoothly. See `image_set_position` for more information.
##
## Wait instruction:
##
## `yield(image, "transition_finished")`
static func image_smooth_position(tr : TextureRect, pos : Vector2, speed : float = 0.0):
    image_smooth_param_vec2(tr, "position", pos, speed if speed > 0.0 else (bg_move_speed if image_is_bg(tr) else tachie_move_speed))

## Set the scale for the given image.
##
## Applies instantly.
static func image_set_scale(tr : TextureRect, scale : Vector2):
    tr.material.set_shader_param("scale", scale)

## Set the scale for the given image smoothly.
##
## Wait instruction:
##
## `yield(image, "transition_finished")`
static func image_smooth_scale(tr : TextureRect, scale : Vector2, speed : float = 0.0):
    image_smooth_param_vec2(tr, "scale", scale, speed if speed > 0.0 else (bg_move_speed if image_is_bg(tr) else tachie_move_speed))

## Set the texture for the given image.
##
## Applies instantly.
static func image_set_texture(tr : TextureRect, tex : Texture):
    tr.texture = tex

## Hide the given image, playing a fade-out animation.
##
## Wait instruction:
##
## `yield(image, "transition_finished")`
static func image_hide(tr : TextureRect, speed : float = 0.0):
    item_hide(tr, speed if speed > 0.0 else (bg_fade_speed if image_is_bg(tr) else tachie_fade_speed))

## Show the given image, playing a fade-in animation.
##
## Wait instruction:
##
## `yield(image, "transition_finished")`
static func image_show(tr : TextureRect, speed : float = 0.0):
    item_show(tr, speed if speed > 0.0 else (bg_fade_speed if image_is_bg(tr) else tachie_fade_speed))

signal textbox_transition_finished
## Hide the current text box, playing a fade-out animation.
##
## Wait instruction:
##
## `yield(CutsceneInstance, "textbox_transition_finished")`
func textbox_hide():
    item_hide(current_textbox, textbox_fade_speed)
    yield(current_textbox, "transition_finished")
    chat_portrait.texture = null
    adv_portrait.texture = null
    emit_signal("textbox_transition_finished")

## Show the current text box, playing a fade-in animation.
##
## Wait instruction:
##
## `yield(CutsceneInstance, "textbox_transition_finished")`
func textbox_show():
    item_show(current_textbox, textbox_fade_speed)
    yield(current_textbox, "transition_finished")
    emit_signal("textbox_transition_finished")

## Switches to the ADV-style textbox.
##
## Applies instantly.
func textbox_set_adv():
    current_textbox = adv_textbox
    adv_textbox.show()
    chat_textbox.hide()
    chat_portrait.texture = null
    adv_portrait.texture = null

func estimate_good_chat_size(text : String):
    var ideal_ar = 2
    var label : RichTextLabel = chat_textbox.get_node("Label")
    var font : Font = label.get_font("normal_font")
    var size = font.get_string_size(text)
    var orig_size = size
    
    if size.x / size.y > ideal_ar:
        var square_sidelen = sqrt(size.x * size.y)
        size = font.get_wordwrap_string_size(text, square_sidelen*2.0)
    
    var line_count = size.y / orig_size.y
    
    size.y += 4 * line_count
    size.x += 5
    
    return size

var chat_pos : Vector2 = Vector2()
var chat_orientation : String = "upleft"

## If in chat-bubble mode, set the face of the next textboxes. Pass `null` to clear it.
##
## Applies instantly.
func chat_set_face(face : Texture, flipped : bool = false):
    chat_portrait.texture = face
    if flipped:
        chat_portrait.material.set_shader_param("scale", Vector2(-1.0, 1.0))
    else:
        chat_portrait.material.set_shader_param("scale", Vector2(1.0, 1.0))

## If in ADV mode, set the face of the next textboxes. Pass `null` to clear it.
##
## Applies instantly.
func adv_set_face(face : Texture, flipped : bool = false):
    adv_portrait.texture = face
    if flipped:
        adv_portrait.material.set_shader_param("scale", Vector2(-1.0, 1.0))
    else:
        adv_portrait.material.set_shader_param("scale", Vector2(1.0, 1.0))

## Switches to the chat-bubble-style textbox.
##
## Applies instantly.
func textbox_set_chat(pos : Vector2, orientation : String = "upleft"):
    current_textbox = chat_textbox
    chat_textbox.show()
    adv_textbox.hide()
    
    chat_pos = pos
    chat_orientation = orientation
    chat_portrait.texture = null
    adv_portrait.texture = null

## Sets the speaker name. To empty, set to an empty string: `""`
##
## Applies instantly. However, the nametag is only visible when text is drawn.
func set_nametag(tag : String):
    adv_textbox.get_node("Nametag").text = tag
    chat_textbox.get_node("Nametag").text = tag

## Used internally.
##
## However, if the chatbox size for a given message is too small, you can use this function to override it.
func fix_chatbox_size(size : Vector2):
    var label : RichTextLabel = chat_textbox.get_node("Label")
    var outer_margin_x = label.margin_left - label.margin_right
    var outer_margin_y = label.margin_top - label.margin_bottom
    
    if chat_portrait.texture:
        outer_margin_x -=  chat_portrait.rect_size.x
    
    size += Vector2(outer_margin_x, outer_margin_y)
    
    var ar = dummy_control.rect_size / dummy_control.rect_size.y
    var center = dummy_control.rect_size/2
    var offset = -size/2
    
    if chat_orientation == "upleft":
        chat_textbox.material.set_shader_param("scale", Vector2(1.0, 1.0))
        offset = Vector2(0, 0)
    elif chat_orientation == "upright":
        chat_textbox.material.set_shader_param("scale", Vector2(-1.0, 1.0))
        offset = Vector2(-size.x, 0)
    elif chat_orientation == "downleft":
        chat_textbox.material.set_shader_param("scale", Vector2(1.0, -1.0))
        offset = Vector2(0, -size.y)
    elif chat_orientation == "downright":
        chat_textbox.material.set_shader_param("scale", Vector2(-1.0, -1.0))
        offset = -size
    
    var new_pos = center + offset + chat_pos*0.5*dummy_control.rect_size.y*ar
    
    chat_textbox.rect_position = new_pos
    chat_textbox.rect_size = size
    
    chat_textbox.material.set_shader_param("screen_size", size)

## Destroy an image, removing it from the scene and freeing its memory.
##
## The underlying texture will continue to exist until you stop using it (write `null` to whatever variable contains it). If you don't have the texture in a variable anywhere, then it will be freed immediately.
func image_destroy(tr : TextureRect):
    if tr in images:
        var _unused = images.erase(tr)
    if tr.get_parent():
        tr.get_parent().remove_child(tr)
    if is_instance_valid(tr):
        tr.queue_free()

class MultiSignalWaiter extends Reference:
    signal all_finished
    var count : int = 0
    func connectify(obj, what):
        count += 1
        yield(obj, what)
        count -= 1
        if count == 0:
            emit_signal("all_finished")

## Call at the end of the cutscene to ensure proper cleanup.
func finish():
    var images_to_wait = []
    for image in images:
        if image.modulate.a > 0.0 and is_instance_valid(image):
            image_hide(image)
            images_to_wait.push_back(image)
    textbox_hide()
    
    var waiter : MultiSignalWaiter = MultiSignalWaiter.new()
    for image in images_to_wait:
        waiter.connectify(image, "transition_finished")
    waiter.connectify(self, "textbox_transition_finished")
    yield(waiter, "all_finished")
    
    queue_free()
    emit_signal("cutscene_finished")

# Used internally.
static func item_transition(tr : CanvasItem, property : String, start, end, speed):
    tr.set_indexed(property, start)
    
    yield(Engine.get_main_loop(), "idle_frame")
    if !is_instance_valid(tr):
        return
    
    var time_passed = 0.0
    while time_passed < 1.0:
        var delta = Engine.get_main_loop().current_scene.get_process_delta_time()
        time_passed = clamp(time_passed + delta * speed, 0.0, 1.0)
        if should_skip_anims(): time_passed = 1.0
        
        tr.set_indexed(property, smoothstep(start, end, time_passed))
        
        yield(Engine.get_main_loop(), "idle_frame")
        if !is_instance_valid(tr):
            return
    
    tr.emit_signal("transition_finished")

# Used internally.
static func item_hide(tr : CanvasItem, speed : float):
    item_transition(tr, "modulate:a", 1.0, 0.0, speed)

# Used internally.
static func item_show(tr : CanvasItem, speed : float):
    item_transition(tr, "modulate:a", 0.0, 1.0, speed)

# _____________________________________________
# |                                           |
# |   MiniMirage internals. Here be dragons.  |
# |                                           |
# _____________________________________________

var adv_textbox : Control = null
var chat_textbox : NinePatchRect = null
var current_textbox : Control = null
var chat_portrait : TextureRect = null
var adv_portrait : TextureRect = null
var _chat_textbox_alignment : float = 0.0

var dummy_control : Control = null

func _ready():
    dummy_control = Control.new()
    add_child(dummy_control)
    dummy_control.anchor_right = 1
    dummy_control.anchor_bottom = 1
    dummy_control.margin_right = 0
    dummy_control.margin_bottom = 0
    
    add_to_group("CutsceneInstance")
    
    adv_textbox = preload("Textbox.tscn").instance()
    chat_textbox = preload("ChatTextbox.tscn").instance()
    add_child(adv_textbox)
    add_child(chat_textbox)
    
    adv_textbox.add_user_signal("transition_finished")
    adv_textbox.modulate.a = 0.0
    chat_textbox.add_user_signal("transition_finished")
    chat_textbox.modulate.a = 0.0
    _chat_textbox_alignment = chat_textbox.get_node("Label").margin_left
    chat_portrait = chat_textbox.get_node("Portrait")
    adv_portrait = adv_textbox.get_node("Portrait")
    
    current_textbox = adv_textbox
    
    VisualServer.canvas_item_set_z_index(adv_textbox.get_canvas_item(), 10)
    VisualServer.canvas_item_set_z_index(chat_textbox.get_canvas_item(), 10)

static func should_advance_input():
    var custom = false
    if InputMap.get_action_list("cutscene_advance").size() > 0:
        custom = Input.is_action_just_pressed("cutscene_advance")
    return custom or Input.is_action_just_pressed("ui_accept")

static func should_use_instant_text():
    var custom = false
    if InputMap.get_action_list("cutscene_instant_text").size() > 0:
        custom = Input.is_action_just_pressed("cutscene_instant_text")
    return custom or Input.is_action_pressed("ui_cancel")

static func should_skip_anims():
    var custom = false
    if InputMap.get_action_list("cutscene_skip").size() > 0:
        custom = Input.is_action_pressed("cutscene_skip")
    return custom or should_advance_input()

var visible_characters : float = 0.0
var skip_timer : float = 0.0
func _process(delta):
    var label = current_textbox.get_node("Label")
    if label.is_visible_in_tree() and current_textbox.modulate.a == 1.0:
        if should_use_instant_text():
            visible_characters = label.get_total_character_count()
        
        if visible_characters >= 0.0 and visible_characters < label.get_total_character_count():
            visible_characters += delta * typein_speed
        
        if should_skip_anims():
            skip_timer += delta
        else:
            skip_timer = 0.0
        
        var do_skip = skip_timer > 1.0/skip_rate
        
        var do_continue = false
        
        if should_advance_input() or do_skip:
            if do_skip:
                visible_characters = label.get_total_character_count()
                do_continue = true
            elif visible_characters >= 0.0 and visible_characters < label.get_total_character_count():
                visible_characters = label.get_total_character_count()
            else:
                do_continue = true
            skip_timer = 0.0
        
        label.visible_characters = int(visible_characters)
        
        adv_textbox.get_node("Nametag").visible_characters = -1
        chat_textbox.get_node("Nametag").visible_characters = -1
        
        if do_continue:
            if should_advance_input():
                yield(Engine.get_main_loop(), "idle_frame")
            emit_signal("cutscene_continue")
    else:
        label.visible_characters = 0
        adv_textbox.get_node("Nametag").visible_characters = 0
        chat_textbox.get_node("Nametag").visible_characters = 0
