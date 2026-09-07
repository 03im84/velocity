@tool
extends EditorPlugin


##
## Custom Editor Themes 1.1
##
## Guarda y aplica esquemas de color
## personalizados para el editor de Godot.
##
## Los datos de usuario permanecen fuera
## del repositorio mediante user://.
##


const THEMES_PATH := (
	"user://velocity_editor_themes.cfg"
)

const MAX_THEME_COUNT: int = 64
const MAX_THEME_NAME_LENGTH: int = 64

const ICON_AND_FONT_COLOR_AUTO: int = 0

const SETTING_FOLLOW_SYSTEM_THEME := (
	"interface/theme/follow_system_theme"
)

const SETTING_COLOR_PRESET := (
	"interface/theme/color_preset"
)

const SETTING_BASE_COLOR := (
	"interface/theme/base_color"
)

const SETTING_ACCENT_COLOR := (
	"interface/theme/accent_color"
)

const SETTING_CONTRAST := (
	"interface/theme/contrast"
)

const SETTING_USE_SYSTEM_ACCENT_COLOR := (
	"interface/theme/use_system_accent_color"
)

const SETTING_ICON_AND_FONT_COLOR := (
	"interface/theme/icon_and_font_color"
)


var _toolbar: HBoxContainer

var _option_button: OptionButton

var _name_edit: LineEdit

var _themes: Dictionary[String, Dictionary] = {}


func _enter_tree(
) -> void:

	_load_themes()

	_build_toolbar()

	add_control_to_container(
		EditorPlugin.CONTAINER_TOOLBAR,
		_toolbar
	)


func _exit_tree(
) -> void:

	if _toolbar == null:
		return

	if not is_instance_valid(
		_toolbar
	):
		_clear_control_references()
		return

	remove_control_from_container(
		EditorPlugin.CONTAINER_TOOLBAR,
		_toolbar
	)

	_toolbar.queue_free()

	_clear_control_references()


# =============================================================================
# TOOLBAR
# =============================================================================

func _build_toolbar(
) -> void:

	_toolbar = HBoxContainer.new()

	var label := Label.new()

	label.text = "  Tema editor:"

	_toolbar.add_child(
		label
	)

	_option_button = OptionButton.new()

	_option_button.custom_minimum_size = Vector2(
		120.0,
		0.0
	)

	_option_button.tooltip_text = (
		"Selecciona un esquema guardado."
	)

	_toolbar.add_child(
		_option_button
	)

	_refresh_option_button()

	var apply_button := Button.new()

	apply_button.text = "Aplicar"

	apply_button.tooltip_text = (
		"Aplica el esquema seleccionado al editor."
	)

	apply_button.pressed.connect(
		_on_apply_pressed
	)

	_toolbar.add_child(
		apply_button
	)

	_name_edit = LineEdit.new()

	_name_edit.placeholder_text = "nombre nuevo"

	_name_edit.custom_minimum_size = Vector2(
		120.0,
		0.0
	)

	_name_edit.max_length = MAX_THEME_NAME_LENGTH

	_name_edit.tooltip_text = (
		"Nombre del esquema que se guardará."
	)

	_toolbar.add_child(
		_name_edit
	)

	var save_button := Button.new()

	save_button.text = "Guardar actual"

	save_button.tooltip_text = (
		"Guarda los colores actuales del editor."
	)

	save_button.pressed.connect(
		_on_save_pressed
	)

	_toolbar.add_child(
		save_button
	)

	var delete_button := Button.new()

	delete_button.text = "Eliminar"

	delete_button.tooltip_text = (
		"Elimina el esquema seleccionado."
	)

	delete_button.pressed.connect(
		_on_delete_pressed
	)

	_toolbar.add_child(
		delete_button
	)


func _clear_control_references(
) -> void:

	_toolbar = null

	_option_button = null

	_name_edit = null


func _refresh_option_button(
	selected_theme_name: String = ""
) -> void:

	if _option_button == null:
		return

	if not is_instance_valid(
		_option_button
	):
		return

	_option_button.clear()

	var theme_names := _get_sorted_theme_names()

	var selected_index: int = -1

	for theme_name: String in theme_names:

		var item_index: int = (
			_option_button.get_item_count()
		)

		_option_button.add_item(
			theme_name
		)

		if theme_name == selected_theme_name:
			selected_index = item_index

	if selected_index >= 0:

		_option_button.select(
			selected_index
		)

		return

	if _option_button.get_item_count() > 0:

		_option_button.select(
			0
		)


func _get_selected_theme_name(
) -> String:

	if _option_button == null:
		return ""

	if not is_instance_valid(
		_option_button
	):
		return ""

	var selected_index: int = (
		_option_button.get_selected()
	)

	if selected_index < 0:
		return ""

	if (
		selected_index
		>= _option_button.get_item_count()
	):
		return ""

	return _option_button.get_item_text(
		selected_index
	)


# =============================================================================
# THEME STORAGE
# =============================================================================

func _load_themes(
) -> void:

	var config := ConfigFile.new()

	var load_error := config.load(
		THEMES_PATH
	)

	if load_error == ERR_FILE_NOT_FOUND:

		_set_default_themes()

		_save_themes()

		return

	if load_error != OK:

		push_warning(
			(
				"Custom Editor Themes could not load "
				+ THEMES_PATH
				+ ". Error code: "
				+ str(load_error)
			)
		)

		_set_default_themes()

		return

	_themes.clear()

	for section: String in config.get_sections():

		if _themes.size() >= MAX_THEME_COUNT:

			push_warning(
				(
					"Custom Editor Themes ignored additional "
					+ "sections because the limit is "
					+ str(MAX_THEME_COUNT)
					+ "."
				)
			)

			break

		var normalized_name := section.strip_edges()

		if normalized_name.is_empty():
			continue

		if (
			normalized_name.length()
			> MAX_THEME_NAME_LENGTH
		):
			continue

		var theme_data := _read_theme_data(
			config,
			section
		)

		if theme_data.is_empty():

			push_warning(
				(
					"Custom Editor Themes ignored invalid "
					+ "section: "
					+ section
				)
			)

			continue

		_themes[
			normalized_name
		] = theme_data


func _save_themes(
) -> bool:

	var config := ConfigFile.new()

	var theme_names := _get_sorted_theme_names()

	for theme_name: String in theme_names:

		var theme_data: Dictionary = _themes[
			theme_name
		]

		config.set_value(
			theme_name,
			"base_color",
			theme_data["base_color"]
		)

		config.set_value(
			theme_name,
			"accent_color",
			theme_data["accent_color"]
		)

		config.set_value(
			theme_name,
			"contrast",
			theme_data["contrast"]
		)

	var save_error := config.save(
		THEMES_PATH
	)

	if save_error == OK:
		return true

	push_error(
		(
			"Custom Editor Themes could not save "
			+ THEMES_PATH
			+ ". Error code: "
			+ str(save_error)
		)
	)

	return false


func _read_theme_data(
	config: ConfigFile,
	section: String
) -> Dictionary:

	var base_color_value: Variant = config.get_value(
		section,
		"base_color",
		null
	)

	var accent_color_value: Variant = config.get_value(
		section,
		"accent_color",
		null
	)

	var contrast_value: Variant = config.get_value(
		section,
		"contrast",
		null
	)

	if not (base_color_value is Color):
		return {}

	if not (accent_color_value is Color):
		return {}

	if not (
		contrast_value is float
		or contrast_value is int
	):
		return {}

	var contrast: float = float(
		contrast_value
	)

	if contrast < -1.0:
		return {}

	if contrast > 1.0:
		return {}

	var base_color: Color = base_color_value

	var accent_color: Color = accent_color_value

	return _create_theme_data(
		base_color,
		accent_color,
		contrast
	)


func _set_default_themes(
) -> void:

	_themes.clear()

	_themes["Oscuro"] = _create_theme_data(
		Color(
			0.145098,
			0.145098,
			0.176471
		),
		Color(
			0.423529,
			0.549020,
			1.0
		),
		0.30
	)

	_themes["Claro"] = _create_theme_data(
		Color(
			0.929412,
			0.949020,
			0.964706
		),
		Color(
			0.090196,
			0.435294,
			0.756863
		),
		-0.06
	)


func _create_theme_data(
	base_color: Color,
	accent_color: Color,
	contrast: float
) -> Dictionary:

	return {
		"base_color": base_color,
		"accent_color": accent_color,
		"contrast": contrast,
	}


func _theme_data_is_valid(
	theme_data: Dictionary
) -> bool:

	if not theme_data.has(
		"base_color"
	):
		return false

	if not theme_data.has(
		"accent_color"
	):
		return false

	if not theme_data.has(
		"contrast"
	):
		return false

	var base_color_value: Variant = theme_data[
		"base_color"
	]

	var accent_color_value: Variant = theme_data[
		"accent_color"
	]

	var contrast_value: Variant = theme_data[
		"contrast"
	]

	if not (base_color_value is Color):
		return false

	if not (accent_color_value is Color):
		return false

	if not (
		contrast_value is float
		or contrast_value is int
	):
		return false

	var contrast: float = float(
		contrast_value
	)

	return (
		contrast >= -1.0
		and contrast <= 1.0
	)


func _get_sorted_theme_names(
) -> Array[String]:

	var theme_names: Array[String] = []

	for theme_name_value: Variant in _themes.keys():

		theme_names.append(
			String(theme_name_value)
		)

	theme_names.sort()

	return theme_names


# =============================================================================
# APPLY
# =============================================================================

func _on_apply_pressed(
) -> void:

	var theme_name := _get_selected_theme_name()

	if theme_name.is_empty():
		return

	if not _themes.has(
		theme_name
	):
		return

	var theme_data: Dictionary = _themes[
		theme_name
	]

	if not _theme_data_is_valid(
		theme_data
	):

		push_error(
			(
				"Custom Editor Themes cannot apply "
				+ "invalid theme: "
				+ theme_name
			)
		)

		return

	var settings := (
		get_editor_interface().get_editor_settings()
	)

	settings.set_setting(
		SETTING_FOLLOW_SYSTEM_THEME,
		false
	)

	settings.set_setting(
		SETTING_COLOR_PRESET,
		"Custom"
	)

	settings.set_setting(
		SETTING_USE_SYSTEM_ACCENT_COLOR,
		false
	)

	settings.set_setting(
		SETTING_ICON_AND_FONT_COLOR,
		ICON_AND_FONT_COLOR_AUTO
	)

	settings.set_setting(
		SETTING_BASE_COLOR,
		theme_data["base_color"]
	)

	settings.set_setting(
		SETTING_ACCENT_COLOR,
		theme_data["accent_color"]
	)

	settings.set_setting(
		SETTING_CONTRAST,
		theme_data["contrast"]
	)


# =============================================================================
# SAVE CURRENT
# =============================================================================

func _on_save_pressed(
) -> void:

	if _name_edit == null:
		return

	if not is_instance_valid(
		_name_edit
	):
		return

	var new_name := _name_edit.text.strip_edges()

	if new_name.is_empty():
		return

	if new_name.length() > MAX_THEME_NAME_LENGTH:
		return

	var replaces_existing := _themes.has(
		new_name
	)

	if (
		not replaces_existing
		and _themes.size() >= MAX_THEME_COUNT
	):

		push_warning(
			(
				"Custom Editor Themes reached the limit of "
				+ str(MAX_THEME_COUNT)
				+ " saved themes."
			)
		)

		return

	var settings := (
		get_editor_interface().get_editor_settings()
	)

	var base_color_value: Variant = settings.get_setting(
		SETTING_BASE_COLOR
	)

	var accent_color_value: Variant = settings.get_setting(
		SETTING_ACCENT_COLOR
	)

	var contrast_value: Variant = settings.get_setting(
		SETTING_CONTRAST
	)

	if not (base_color_value is Color):
		return

	if not (accent_color_value is Color):
		return

	if not (
		contrast_value is float
		or contrast_value is int
	):
		return

	var contrast: float = float(
		contrast_value
	)

	if contrast < -1.0:
		return

	if contrast > 1.0:
		return

	var base_color: Color = base_color_value

	var accent_color: Color = accent_color_value

	var previous_data: Dictionary = {}

	if replaces_existing:

		previous_data = _themes[
			new_name
		].duplicate(
			true
		)

	_themes[new_name] = _create_theme_data(
		base_color,
		accent_color,
		contrast
	)

	if not _save_themes():

		if replaces_existing:

			_themes[
				new_name
			] = previous_data

		else:

			_themes.erase(
				new_name
			)

		return

	_refresh_option_button(
		new_name
	)

	_name_edit.text = ""


# =============================================================================
# DELETE
# =============================================================================

func _on_delete_pressed(
) -> void:

	var theme_name := _get_selected_theme_name()

	if theme_name.is_empty():
		return

	if not _themes.has(
		theme_name
	):
		return

	var deleted_data: Dictionary = _themes[
		theme_name
	].duplicate(
		true
	)

	_themes.erase(
		theme_name
	)

	if not _save_themes():

		_themes[
			theme_name
		] = deleted_data

		return

	_refresh_option_button()