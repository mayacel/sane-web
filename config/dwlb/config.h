#define HEX_COLOR(hex) \
    { .red   = ((hex >> 24) & 0xff) * 257, \
      .green = ((hex >> 16) & 0xff) * 257, \
      .blue  = ((hex >> 8)  & 0xff) * 257, \
      .alpha = (hex & 0xff) * 257 }

/* Sane Web v6: status bar = status. No dashboard, no decorative metrics. */
static bool ipc = false;
static bool hidden = false;
static bool bottom = false;
static bool hide_vacant = false;
static uint32_t vertical_padding = 1;
static bool status_commands = true;
static bool center_title = false;
static bool custom_title = false;
static bool active_color_title = false;
static uint32_t buffer_scale = 1;
static char *fontstr = "Terminus:size=11";
static char *tags_names[] = { "1", "2", "3", "4", "5" };

/* One coherent shell palette. Content inside windows is free to be content. */
static pixman_color_t active_fg_color = HEX_COLOR(0xfffaf0ff);
static pixman_color_t active_bg_color = HEX_COLOR(0x6f8448ff);
static pixman_color_t occupied_fg_color = HEX_COLOR(0x566438ff);
static pixman_color_t occupied_bg_color = HEX_COLOR(0xf2ead7ff);
static pixman_color_t inactive_fg_color = HEX_COLOR(0x66665dff);
static pixman_color_t inactive_bg_color = HEX_COLOR(0xf2ead7ff);
static pixman_color_t urgent_fg_color = HEX_COLOR(0xfffaf0ff);
static pixman_color_t urgent_bg_color = HEX_COLOR(0xb56745ff);
static pixman_color_t middle_bg_color = HEX_COLOR(0xf2ead7ff);
static pixman_color_t middle_bg_color_selected = HEX_COLOR(0xf2ead7ff);
