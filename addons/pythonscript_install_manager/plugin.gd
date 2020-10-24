tool
extends EditorPlugin

const menu_item_name = "Manage Python..."
var manager_node

func _enter_tree():
    add_tool_menu_item(menu_item_name, self, "_menu_item_clicked")
    manager_node = preload("manager.tscn").instance()
    get_editor_interface().get_editor_viewport().add_child(manager_node)

func _exit_tree():
    remove_tool_menu_item(menu_item_name)
    if manager_node:
        manager_node.queue_free()
        manager_node = null

func _menu_item_clicked(arg):
    manager_node.popup_centered()

func enable_plugin():
    manager_node.popup_centered()
