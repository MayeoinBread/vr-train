extends Node3D

var xr_interface: XRInterface

func _ready():
	await get_tree().process_frame
	initialise_xr()

func initialise_xr():
	print("XR interfaces: ", XRServer.get_interfaces())
	
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface:
		print("Found OpenXR")
		
		var success = xr_interface.initialize()
		print("Init success: ", success)
		print("Is initialised: ", xr_interface.is_initialized())
		
		if success and xr_interface.is_initialized():
			print("OpenXR initialized successfully")

			# Turn off v-sync!
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

			# Change our main viewport to output to the HMD
			get_viewport().use_xr = true
		else:
			print("OpenXR not initialized, please check if your headset is connected")
