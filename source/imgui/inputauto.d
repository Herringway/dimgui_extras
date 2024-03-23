module imgui.inputauto;

import d_imgui.imgui_h;
import ImGui = d_imgui;

bool InputAuto(T)(string label, ref T v, ImGuiInputTextFlags flags = ImGuiInputTextFlags.None) {
	static if (!is(T == char[])) {
		T step = 1;
		T step_fast = 100;
	}
	static if (is(T == ubyte)) {
		return ImGui.InputScalar(label, ImGuiDataType.U8, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == byte)) {
		return ImGui.InputScalar(label, ImGuiDataType.S8, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == ushort)) {
		return ImGui.InputScalar(label, ImGuiDataType.U16, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == short)) {
		return ImGui.InputScalar(label, ImGuiDataType.S16, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == uint)) {
		return ImGui.InputScalar(label, ImGuiDataType.U32, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == int)) {
		return ImGui.InputScalar(label, ImGuiDataType.S32, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == ulong)) {
		return ImGui.InputScalar(label, ImGuiDataType.U64, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == long)) {
		return ImGui.InputScalar(label, ImGuiDataType.S64, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%d", flags);
	} else static if (is(T == float)) {
		return ImGui.InputScalar(label, ImGuiDataType.Float, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%.3f", flags);
	} else static if (is(T == double)) {
		return ImGui.InputScalar(label, ImGuiDataType.Double, cast(void*)&v, cast(void*)(step > 0 ? &step : null), cast(void*)(step_fast > 0 ? &step_fast : null), "%.3f", flags);
	} else static if (is(T == char[])) {
		return InputString(label, &v, flags);
	} else static assert(0, "Cannot handle this type");
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
