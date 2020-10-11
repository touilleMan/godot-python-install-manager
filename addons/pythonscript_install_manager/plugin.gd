tool
extends EditorPlugin

const menu_item_name = "Manage Python..."

var settings_node

func _enter_tree():
    add_tool_menu_item(menu_item_name, self, "_manage_python_clicked")
    settings_node = preload("settings.tscn").instance()
    get_editor_interface().get_editor_viewport().add_child(settings_node)

func _exit_tree():
    remove_tool_menu_item(menu_item_name)
    if settings_node:
        settings_node.queue_free()
        settings_node = null

func _manage_python_clicked(arg):
    settings_node.popup_centered()

func enable_plugin():
    settings_node.popup_centered()
