module imgui.logconsole;

import std.algorithm.searching;
import std.conv;
import std.format;
import std.logger;

import d_imgui.imgui_h;
import ImGui = d_imgui;

class LogConsole : Logger {
	LogEntry[] Items;
	bool ShowDate = false;
	bool ShowTime = true;
	bool AutoScroll = true;
	bool ScrollToBottom = false;

	this() {
		this(globalLogLevel);
	}
	this(LogLevel level) {
		super(level);
	}

	void ClearLog() {
		Items = [];
	}

	override void writeLogMsg(ref LogEntry msg) {
		Items ~= msg;
	}

	void Draw(const string title) {
		bool _ = true;
		Draw(title, &_);
	}
	void Draw(const string title, bool* p_open) {
		ImGui.SetNextWindowSize(ImVec2(520, 600), ImGuiCond.FirstUseEver);
		if (!ImGui.Begin(title, p_open)) {
			ImGui.End();
			return;
		}

		if (ImGui.SmallButton("Clear")) {
			ClearLog();
		}
		ImGui.SameLine();
		bool copy_to_clipboard = ImGui.SmallButton("Copy");

		ImGui.Separator();

		// Reserve enough left-over height for 1 separator + 1 input text
		const float footer_height_to_reserve = ImGui.GetStyle().ItemSpacing.y + ImGui.GetFrameHeightWithSpacing();
		if (ImGui.BeginChild("ScrollingRegion", ImVec2(0, -footer_height_to_reserve), false, ImGuiWindowFlags.HorizontalScrollbar)) {
			if (ImGui.BeginPopupContextWindow()) {
				if (ImGui.Selectable("Clear")) ClearLog();
				ImGui.EndPopup();
			}

			ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(4, 1)); // Tighten spacing
			if (copy_to_clipboard) {
				ImGui.LogToClipboard();
			}
			foreach (item; Items) {
				bool written;
				ImGui.BeginGroup();
				if (ShowDate) {
					ImGui.Text("%02d-%02d-%02d", item.timestamp.year, cast(ubyte)item.timestamp.month, item.timestamp.day);
					ImGui.SameLine();
				}
				if (ShowTime) {
					ImGui.Text("%02d:%02d:%07.4f", item.timestamp.hour, item.timestamp.minute, item.timestamp.second + item.timestamp.fracSecs.total!"hnsecs" / 10_000_000.0);
					ImGui.SameLine();
				}
				ImGui.TextUnformatted("[");
				ImGui.SameLine();
				final switch (item.logLevel) {
					case LogLevel.all:
					case LogLevel.off:
						ImGui.PushStyleColor(ImGuiCol.Text, 0xFFFFFFFF);
						break;
					case LogLevel.critical:
						ImGui.PushStyleColor(ImGuiCol.Text, 0xFF0000FF);
						break;
					case LogLevel.error:
						ImGui.PushStyleColor(ImGuiCol.Text, 0xFF0000AF);
						break;
					case LogLevel.fatal:
						ImGui.PushStyleColor(ImGuiCol.Text, 0xFF00007F);
						break;
					case LogLevel.info:
						ImGui.PushStyleColor(ImGuiCol.Text, 0xFFCFCFCF);
						break;
					case LogLevel.trace:
						ImGui.PushStyleColor(ImGuiCol.Text, 0xFF8F8F8F);
						break;
					case LogLevel.warning:
						ImGui.PushStyleColor(ImGuiCol.Text, 0xFF5F5FCF);
						break;
				}
				ImGui.TextUnformatted(item.logLevel.text);
				ImGui.PopStyleColor();
				ImGui.SameLine();
				ImGui.TextUnformatted("]");
				ImGui.SameLine();
				ImGui.TextUnformatted(item.msg);
				ImGui.EndGroup();
				if (ImGui.BeginItemTooltip()) {
					ImGui.Text("%s:%d", item.file, item.line);
					ImGui.EndTooltip();
				}
			}
			if (copy_to_clipboard) {
				ImGui.LogFinish();
			}

			// Keep up at the bottom of the scroll region if we were already at the bottom at the beginning of the frame.
			// Using a scrollbar or mouse-wheel will take away from the bottom edge.
			if (ScrollToBottom || (AutoScroll && ImGui.GetScrollY() >= ImGui.GetScrollMaxY())) {
				ImGui.SetScrollHereY(1.0f);
			}
			ScrollToBottom = false;

			ImGui.PopStyleVar();
		}
		ImGui.EndChild();

		// Auto-focus on window apparition
		ImGui.SetItemDefaultFocus();

		ImGui.End();
	}
}