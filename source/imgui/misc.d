module imgui.misc;
import d_imgui.imgui_h;
import ImGui = d_imgui;

bool imguiAteKeyboard() {
	const io = &ImGui.GetIO();
	return io.WantCaptureKeyboard;
}
