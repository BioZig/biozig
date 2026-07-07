const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const file = try std.fs.cwd().openFile("index.html", .{ .mode = .read_write });
    defer file.close();

    const content = try file.readToEndAlloc(alloc, 1024 * 1024 * 10);

    // Find CSS start
    const css_start_str = "    /* ══════════════════════════════════════════════════════════\n       LOGOS — Mark C style: chromosome morphology marks";
    const css_end_str = "  </style>";

    const idx_start = std.mem.indexOf(u8, content, css_start_str) orelse return error.NotFound;
    const idx_end = std.mem.indexOfPos(u8, content, idx_start, css_end_str) orelse return error.NotFound;

    const logo_css =
        \\    /* ════ BIOZIG GLOBAL HEADER LOGO ════ */
        \\    .bz-logo-sm { display: flex; align-items: center; gap: 8px; }
        \\    .bz-logo-sm .bz-chr { display: flex; align-items: baseline; height: auto; }
        \\    .bz-logo-sm .bz-chr-band3 {
        \\      font-family: 'Inter', sans-serif; font-size: 26px; font-weight: 900; line-height: 1;
        \\      background: repeating-linear-gradient(180deg, #f7a41d 0%, #f7a41d 8%, #3b82f6 8%, #3b82f6 12%);
        \\      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
        \\      margin-right: -2px;
        \\    }
        \\    .bz-logo-sm .bz-chr-band7 {
        \\      font-family: 'Inter', sans-serif; font-size: 21px; font-weight: 900; line-height: 1;
        \\      background: repeating-linear-gradient(180deg, #f7a41d 0%, #f7a41d 10%, #3b82f6 10%, #3b82f6 15%);
        \\      -webkit-background-clip: text; -webkit-text-fill-color: transparent;
        \\    }
        \\    .bz-logo-sm .bz-wordmark {
        \\      font-family: 'Inter', sans-serif; font-weight: 700; font-size: 15px; letter-spacing: 2px;
        \\      margin-top: 0; display: flex; align-items: center;
        \\    }
        \\    .bz-logo-sm .w-bio { color: rgba(255,255,255,0.4); }
        \\    .bz-logo-sm .w-zig { color: rgba(255,255,255,0.9); }
        \\    [data-theme="light"] .bz-logo-sm .w-bio { color: rgba(26,16,6,0.4); }
        \\    [data-theme="light"] .bz-logo-sm .w-zig { color: rgba(26,16,6,0.8); }
        \\
    ;

    var res1 = try std.mem.replaceOwned(u8, alloc, content, content[idx_start..idx_end], logo_css);

    const tab_str = "  <button class=\"tab\"    onclick=\"go('logos',this)\">05 — Logo Marks</button>\n";
    res1 = try std.mem.replaceOwned(u8, alloc, res1, tab_str, "");

    const sm_logo =
        \\      <div class="bz-logo-sm">
        \\        <div class="bz-chr">
        \\          <div class="bz-chr-band3">3</div>
        \\          <div class="bz-chr-band7">7</div>
        \\        </div>
        \\        <div class="bz-wordmark"><span class="w-bio">BIO</span><span class="w-zig">ZIG</span></div>
        \\      </div>
    ;

    res1 = try std.mem.replaceOwned(u8, alloc, res1, "<span class=\"d1-mark\">Bio<b>Zig</b></span>", sm_logo);
    res1 = try std.mem.replaceOwned(u8, alloc, res1, "<span class=\"d2-id\">Bio<em>Zig</em></span>", sm_logo);
    res1 = try std.mem.replaceOwned(u8, alloc, res1, "<div class=\"d3-hd-part\">BIOZIG</div>", sm_logo);

    const d4_logo =
        \\        <div style="display:flex; align-items:center; gap: 8px;">
        \\          <div class="bz-logo-sm">
        \\            <div class="bz-chr">
        \\              <div class="bz-chr-band3">3</div>
        \\              <div class="bz-chr-band7">7</div>
        \\            </div>
        \\            <div class="bz-wordmark"><span class="w-bio">BIO</span><span class="w-zig">ZIG</span></div>
        \\          </div>
        \\          <span class="d4-nb-title" style="margin-left:4px">· Field Notes</span>
        \\        </div>
    ;
    res1 = try std.mem.replaceOwned(u8, alloc, res1, "<span class=\"d4-nb-title\">Bio<em>Zig</em> · Field Notes</span>", d4_logo);

    const panel_start = "<!-- ════════════════════════════════════ LOGOS ═══ -->";
    const panel_end = "</div><!-- end logos panel -->\n";

    const p_start = std.mem.indexOf(u8, res1, panel_start) orelse return error.NotFound2;
    const p_end = std.mem.indexOfPos(u8, res1, p_start, panel_end) orelse return error.NotFound2;

    const final = try std.mem.replaceOwned(u8, alloc, res1, res1[p_start .. p_end + panel_end.len], "");

    try file.seekTo(0);
    try file.setEndPos(0);
    try file.writeAll(final);
    std.debug.print("Done\n", .{});
}
