module imgui.inputauto;

import d_imgui.imgui_h;
import ImGui = d_imgui;

bool InputAuto(T)(string label, T* v, int step = 1, int step_fast = 100, ImGuiInputTextFlags flags = ImGuiInputTextFlags.None) {
	static if (is(T == ubyte)) {
		enum type = ImGuiDataType.U8;
	} else static if (is(T == byte)) {
		enum type = ImGuiDataType.S8;
	} else static if (is(T == ushort)) {
		enum type = ImGuiDataType.U16;
	} else static if (is(T == short)) {
		enum type = ImGuiDataType.S16;
	} else static if (is(T == uint)) {
		enum type = ImGuiDataType.U32;
	} else static if (is(T == int)) {
		enum type = ImGuiDataType.S32;
	} else static if (is(T == ulong)) {
		enum type = ImGuiDataType.U64;
	} else static if (is(T == long)) {
		enum type = ImGuiDataType.S64;
	} else static if (is(T == float)) {
		enum type = ImGuiDataType.Float;
	} else static if (is(T == double)) {
		enum type = ImGuiDataType.Double;
	} else static assert(0, "Cannot handle this type");
	return ImGui.InputScalar(label, type, cast(void*)v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
}

bool InputString(string label, char[]* v, ImGuiInputTextFlags flags = ImGuiInputTextFlags.None, ImVec2 multilineDimensions = ImVec2.init) {
	static struct UserData {
		char[]* buf;
	}
	static int callback(ImGuiInputTextCallbackData* data) {
		auto userdata = cast(UserData*)data.UserData;
		import std.logger; debug infof("%s %s %s %s", *userdata.buf, data.BufTextLen, data.Buf, cast(ImGuiInputTextFlags)data.EventFlag);
		if (data.EventFlag == ImGuiInputTextFlags.CallbackResize) {
			if (data.BufTextLen < 0) {
				data.BufTextLen = 0;
			}
			//userdata.buf.length = data.BufTextLen + 1;

			data.Buf = *userdata.buf;
			//data.Buf = data.Buf[0 .. $ - 1];
			//*userdata.buf = (*userdata.buf)[0..$-1];
		}
		return 0;
	}
	auto userdata = UserData(v);
	if (multilineDimensions != ImVec2.init) {
		return ImGui.InputTextMultiline(label, *v, multilineDimensions, flags | ImGuiInputTextFlags.CallbackResize, &callback, &userdata);
	} else {
		return ImGui.InputText(label, *v, flags | ImGuiInputTextFlags.CallbackResize, &callback, &userdata);
	}
}
