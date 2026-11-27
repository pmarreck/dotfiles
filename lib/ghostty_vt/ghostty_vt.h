/* libghostty-vt declarations for the LuaJIT FFI, copied from its headers
 * (include/ghostty/vt/ *.h) with the GHOSTTY_API macro removed. They match the
 * release flake.lock pins, 0.1.0-unstable-2026-07-20: every struct, prototype,
 * and constant here was compared with that release's headers, and terminal.lua
 * refuses any other version, since a changed layout would corrupt calls. */
typedef enum {
    GHOSTTY_SUCCESS = 0,
    GHOSTTY_OUT_OF_MEMORY = -1,
    GHOSTTY_INVALID_VALUE = -2,
    GHOSTTY_OUT_OF_SPACE = -3,
    GHOSTTY_NO_VALUE = -4,
    GHOSTTY_IO_ERROR = -5,
    GHOSTTY_LIMIT_EXCEEDED = -6,
    GHOSTTY_RESULT_MAX_VALUE = 2147483647,
} GhosttyResult;

typedef struct GhosttyTerminalImpl* GhosttyTerminal;
typedef struct GhosttyKittyGraphicsImpl* GhosttyKittyGraphics;
typedef const struct GhosttyKittyGraphicsImageImpl* GhosttyKittyGraphicsImage;
typedef struct GhosttyKittyGraphicsPlacementIteratorImpl* GhosttyKittyGraphicsPlacementIterator;
typedef struct GhosttyFormatterImpl* GhosttyFormatter;

typedef enum {
  GHOSTTY_FORMATTER_FORMAT_PLAIN,
  GHOSTTY_FORMATTER_FORMAT_VT,
  GHOSTTY_FORMATTER_FORMAT_HTML,
  GHOSTTY_FORMATTER_FORMAT_MAX_VALUE = 2147483647,
} GhosttyFormatterFormat;

typedef struct {
  const uint8_t* ptr;
  size_t len;
} GhosttyString;

typedef struct {
    void* (*alloc)(void *ctx, size_t len, uint8_t alignment, uintptr_t ret_addr);
    bool (*resize)(void *ctx, void *memory, size_t memory_len, uint8_t alignment, size_t new_len, uintptr_t ret_addr);
    void* (*remap)(void *ctx, void *memory, size_t memory_len, uint8_t alignment, size_t new_len, uintptr_t ret_addr);
    void (*free)(void *ctx, void *memory, size_t memory_len, uint8_t alignment, uintptr_t ret_addr);
} GhosttyAllocatorVtable;

typedef struct GhosttyAllocator {
    void *ctx;
    const GhosttyAllocatorVtable *vtable;
} GhosttyAllocator;

uint8_t* ghostty_alloc(const GhosttyAllocator* allocator, size_t len);
void ghostty_free(const GhosttyAllocator* allocator, uint8_t* ptr, size_t len);

typedef enum {
  GHOSTTY_BUILD_INFO_INVALID = 0,
  GHOSTTY_BUILD_INFO_SIMD = 1,
  GHOSTTY_BUILD_INFO_KITTY_GRAPHICS = 2,
  GHOSTTY_BUILD_INFO_TMUX_CONTROL_MODE = 3,
  GHOSTTY_BUILD_INFO_OPTIMIZE = 4,
  GHOSTTY_BUILD_INFO_VERSION_STRING = 5,
  GHOSTTY_BUILD_INFO_VERSION_MAJOR = 6,
  GHOSTTY_BUILD_INFO_VERSION_MINOR = 7,
  GHOSTTY_BUILD_INFO_VERSION_PATCH = 8,
  GHOSTTY_BUILD_INFO_VERSION_PRE = 9,
  GHOSTTY_BUILD_INFO_VERSION_BUILD = 10,
  GHOSTTY_BUILD_INFO_MAX_VALUE = 2147483647,
} GhosttyBuildInfo;
GhosttyResult ghostty_build_info(GhosttyBuildInfo data, void *out);

typedef enum {
    GHOSTTY_COLOR_SCHEME_LIGHT = 0,
    GHOSTTY_COLOR_SCHEME_DARK = 1,
    GHOSTTY_COLOR_SCHEME_MAX_VALUE = 2147483647,
} GhosttyColorScheme;

typedef struct {
    uint16_t conformance_level;
    uint16_t features[64];
    size_t num_features;
} GhosttyDeviceAttributesPrimary;

typedef struct {
    uint16_t device_type;
    uint16_t firmware_version;
    uint16_t rom_cartridge;
} GhosttyDeviceAttributesSecondary;

typedef struct {
    uint32_t unit_id;
} GhosttyDeviceAttributesTertiary;

typedef struct {
    GhosttyDeviceAttributesPrimary primary;
    GhosttyDeviceAttributesSecondary secondary;
    GhosttyDeviceAttributesTertiary tertiary;
} GhosttyDeviceAttributes;

typedef struct {
    uint16_t rows;
    uint16_t columns;
    uint32_t cell_width;
    uint32_t cell_height;
} GhosttySizeReportSize;

typedef struct {
  size_t size;
  void *node;
  uint16_t x;
  uint16_t y;
} GhosttyGridRef;

typedef struct {
  size_t size;
  GhosttyGridRef start;
  GhosttyGridRef end;
  bool rectangle;
} GhosttySelection;

typedef uint16_t GhosttyMode;

typedef void (*GhosttyTerminalBellFn)(GhosttyTerminal terminal, void* userdata);
typedef bool (*GhosttyTerminalColorSchemeFn)(GhosttyTerminal terminal,
                                             void* userdata,
                                             GhosttyColorScheme* out_scheme);
typedef bool (*GhosttyTerminalDeviceAttributesFn)(GhosttyTerminal terminal,
                                                   void* userdata,
                                                   GhosttyDeviceAttributes* out_attrs);
typedef GhosttyString (*GhosttyTerminalEnquiryFn)(GhosttyTerminal terminal,
                                                   void* userdata);
typedef bool (*GhosttyTerminalSizeFn)(GhosttyTerminal terminal,
                                      void* userdata,
                                      GhosttySizeReportSize* out_size);
typedef void (*GhosttyTerminalWritePtyFn)(GhosttyTerminal terminal,
                                          void* userdata,
                                          const uint8_t* data,
                                          size_t len);
typedef GhosttyString (*GhosttyTerminalXtversionFn)(GhosttyTerminal terminal,
                                                     void* userdata);

typedef enum {
  GHOSTTY_TERMINAL_OPT_USERDATA = 0,
  GHOSTTY_TERMINAL_OPT_WRITE_PTY = 1,
  GHOSTTY_TERMINAL_OPT_BELL = 2,
  GHOSTTY_TERMINAL_OPT_ENQUIRY = 3,
  GHOSTTY_TERMINAL_OPT_XTVERSION = 4,
  GHOSTTY_TERMINAL_OPT_TITLE_CHANGED = 5,
  GHOSTTY_TERMINAL_OPT_SIZE = 6,
  GHOSTTY_TERMINAL_OPT_COLOR_SCHEME = 7,
  GHOSTTY_TERMINAL_OPT_DEVICE_ATTRIBUTES = 8,
  GHOSTTY_TERMINAL_OPT_TITLE = 9,
  GHOSTTY_TERMINAL_OPT_PWD = 10,
  GHOSTTY_TERMINAL_OPT_COLOR_FOREGROUND = 11,
  GHOSTTY_TERMINAL_OPT_COLOR_BACKGROUND = 12,
  GHOSTTY_TERMINAL_OPT_COLOR_CURSOR = 13,
  GHOSTTY_TERMINAL_OPT_COLOR_PALETTE = 14,
  GHOSTTY_TERMINAL_OPT_KITTY_IMAGE_STORAGE_LIMIT = 15,
  GHOSTTY_TERMINAL_OPT_KITTY_IMAGE_MEDIUM_FILE = 16,
  GHOSTTY_TERMINAL_OPT_KITTY_IMAGE_MEDIUM_TEMP_FILE = 17,
  GHOSTTY_TERMINAL_OPT_KITTY_IMAGE_MEDIUM_SHARED_MEM = 18,
  GHOSTTY_TERMINAL_OPT_APC_MAX_BYTES = 19,
  GHOSTTY_TERMINAL_OPT_APC_MAX_BYTES_KITTY = 20,
  GHOSTTY_TERMINAL_OPT_SELECTION = 21,
  GHOSTTY_TERMINAL_OPT_DEFAULT_CURSOR_STYLE = 22,
  GHOSTTY_TERMINAL_OPT_DEFAULT_CURSOR_BLINK = 23,
  GHOSTTY_TERMINAL_OPT_GLYPH_PROTOCOL = 24,
  GHOSTTY_TERMINAL_OPT_PWD_CHANGED = 25,
  GHOSTTY_TERMINAL_OPT_CLIPBOARD_WRITE = 26,
  GHOSTTY_TERMINAL_OPT_SCROLLBACK_MAX_BYTES = 27,
  GHOSTTY_TERMINAL_OPT_SCROLLBACK_MAX_LINES = 28,
  GHOSTTY_TERMINAL_OPT_DESKTOP_NOTIFICATION = 29,
  GHOSTTY_TERMINAL_OPT_PROGRESS_REPORT = 30,
  GHOSTTY_TERMINAL_OPT_CONTINUATION_MAX_BYTES = 31,
  GHOSTTY_TERMINAL_OPT_TITLE_REPORT = 32,
  GHOSTTY_TERMINAL_OPT_MODE_DEFAULT = 33,
  GHOSTTY_TERMINAL_OPT_MODE = 34,
  GHOSTTY_TERMINAL_OPT_MAX_VALUE = 2147483647,
} GhosttyTerminalOption;

typedef enum {
  GHOSTTY_TERMINAL_DATA_INVALID = 0,
  GHOSTTY_TERMINAL_DATA_COLS = 1,
  GHOSTTY_TERMINAL_DATA_ROWS = 2,
  GHOSTTY_TERMINAL_DATA_CURSOR_X = 3,
  GHOSTTY_TERMINAL_DATA_CURSOR_Y = 4,
  GHOSTTY_TERMINAL_DATA_CURSOR_PENDING_WRAP = 5,
  GHOSTTY_TERMINAL_DATA_ACTIVE_SCREEN = 6,
  GHOSTTY_TERMINAL_DATA_CURSOR_VISIBLE = 7,
  GHOSTTY_TERMINAL_DATA_KITTY_KEYBOARD_FLAGS = 8,
  GHOSTTY_TERMINAL_DATA_SCROLLBAR = 9,
  GHOSTTY_TERMINAL_DATA_CURSOR_STYLE = 10,
  GHOSTTY_TERMINAL_DATA_MOUSE_TRACKING = 11,
  GHOSTTY_TERMINAL_DATA_TITLE = 12,
  GHOSTTY_TERMINAL_DATA_PWD = 13,
  GHOSTTY_TERMINAL_DATA_TOTAL_ROWS = 14,
  GHOSTTY_TERMINAL_DATA_SCROLLBACK_ROWS = 15,
  GHOSTTY_TERMINAL_DATA_WIDTH_PX = 16,
  GHOSTTY_TERMINAL_DATA_HEIGHT_PX = 17,
  GHOSTTY_TERMINAL_DATA_COLOR_FOREGROUND = 18,
  GHOSTTY_TERMINAL_DATA_COLOR_BACKGROUND = 19,
  GHOSTTY_TERMINAL_DATA_COLOR_CURSOR = 20,
  GHOSTTY_TERMINAL_DATA_COLOR_PALETTE = 21,
  GHOSTTY_TERMINAL_DATA_COLOR_FOREGROUND_DEFAULT = 22,
  GHOSTTY_TERMINAL_DATA_COLOR_BACKGROUND_DEFAULT = 23,
  GHOSTTY_TERMINAL_DATA_COLOR_CURSOR_DEFAULT = 24,
  GHOSTTY_TERMINAL_DATA_COLOR_PALETTE_DEFAULT = 25,
  GHOSTTY_TERMINAL_DATA_KITTY_IMAGE_STORAGE_LIMIT = 26,
  GHOSTTY_TERMINAL_DATA_KITTY_IMAGE_MEDIUM_FILE = 27,
  GHOSTTY_TERMINAL_DATA_KITTY_IMAGE_MEDIUM_TEMP_FILE = 28,
  GHOSTTY_TERMINAL_DATA_KITTY_IMAGE_MEDIUM_SHARED_MEM = 29,
  GHOSTTY_TERMINAL_DATA_KITTY_GRAPHICS = 30,
  GHOSTTY_TERMINAL_DATA_SELECTION = 31,
  GHOSTTY_TERMINAL_DATA_VIEWPORT_ACTIVE = 32,
  GHOSTTY_TERMINAL_DATA_VT_PROCESSING_ERROR = 33,
  GHOSTTY_TERMINAL_DATA_SCROLLBACK_MAX_BYTES = 34,
  GHOSTTY_TERMINAL_DATA_SCROLLBACK_MAX_LINES = 35,
  GHOSTTY_TERMINAL_DATA_CONTINUATION_MAX_BYTES = 36,
  GHOSTTY_TERMINAL_DATA_MODE = 37,
  GHOSTTY_TERMINAL_DATA_MAX_VALUE = 2147483647,
} GhosttyTerminalData;

typedef struct {
  uint16_t cols;
  uint16_t rows;
  size_t max_scrollback;
} GhosttyTerminalOptions;
GhosttyResult ghostty_terminal_new(const GhosttyAllocator* allocator,
                                   GhosttyTerminal* terminal,
                                   GhosttyTerminalOptions options);
void ghostty_terminal_free(GhosttyTerminal terminal);
void ghostty_terminal_reset(GhosttyTerminal terminal);
GhosttyResult ghostty_terminal_resize(GhosttyTerminal terminal,
                                      uint16_t cols,
                                      uint16_t rows,
                                      uint32_t cell_width_px,
                                      uint32_t cell_height_px);
GhosttyResult ghostty_terminal_set(GhosttyTerminal terminal,
                                   GhosttyTerminalOption option,
                                   const void* value);
void ghostty_terminal_vt_write(GhosttyTerminal terminal,
                               const uint8_t* data,
                               size_t len);
GhosttyResult ghostty_terminal_get(GhosttyTerminal terminal,
                                   GhosttyTerminalData data,
                                   void *out);
GhosttyResult ghostty_terminal_get_multi(GhosttyTerminal terminal,
                                         size_t count,
                                         const GhosttyTerminalData* keys,
                                         void** values,
                                         size_t* out_written);

typedef struct {
  size_t size;
  bool cursor;
  bool style;
  bool hyperlink;
  bool protection;
  bool kitty_keyboard;
  bool charsets;
} GhosttyFormatterScreenExtra;

typedef struct {
  size_t size;
  bool palette;
  bool modes;
  bool scrolling_region;
  bool tabstops;
  bool pwd;
  bool keyboard;
  GhosttyFormatterScreenExtra screen;
} GhosttyFormatterTerminalExtra;

typedef struct {
  size_t size;
  GhosttyFormatterFormat emit;
  bool unwrap;
  bool trim;
  GhosttyFormatterTerminalExtra extra;
  const GhosttySelection *selection;
} GhosttyFormatterTerminalOptions;

GhosttyResult ghostty_formatter_terminal_new(
    const GhosttyAllocator* allocator,
    GhosttyFormatter* formatter,
    GhosttyTerminal terminal,
    GhosttyFormatterTerminalOptions options);
GhosttyResult ghostty_formatter_format_buf(GhosttyFormatter formatter,
                                           uint8_t* buf,
                                           size_t buf_len,
                                           size_t* out_written);
GhosttyResult ghostty_formatter_format_alloc(GhosttyFormatter formatter,
                                             const GhosttyAllocator* allocator,
                                             uint8_t** out_ptr,
                                             size_t* out_len);
void ghostty_formatter_free(GhosttyFormatter formatter);

typedef enum {
  GHOSTTY_KITTY_GRAPHICS_DATA_INVALID = 0,
  GHOSTTY_KITTY_GRAPHICS_DATA_PLACEMENT_ITERATOR = 1,
  GHOSTTY_KITTY_GRAPHICS_DATA_GENERATION = 2,
  GHOSTTY_KITTY_GRAPHICS_DATA_MAX_VALUE = 2147483647,
} GhosttyKittyGraphicsData;

typedef enum {
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_INVALID = 0,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_IMAGE_ID = 1,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_PLACEMENT_ID = 2,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_IS_VIRTUAL = 3,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_X_OFFSET = 4,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_Y_OFFSET = 5,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_SOURCE_X = 6,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_SOURCE_Y = 7,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_SOURCE_WIDTH = 8,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_SOURCE_HEIGHT = 9,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_COLUMNS = 10,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_ROWS = 11,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_Z = 12,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_DATA_MAX_VALUE = 2147483647,
} GhosttyKittyGraphicsPlacementData;

typedef enum {
  GHOSTTY_KITTY_PLACEMENT_LAYER_ALL = 0,
  GHOSTTY_KITTY_PLACEMENT_LAYER_BELOW_BG = 1,
  GHOSTTY_KITTY_PLACEMENT_LAYER_BELOW_TEXT = 2,
  GHOSTTY_KITTY_PLACEMENT_LAYER_ABOVE_TEXT = 3,
  GHOSTTY_KITTY_PLACEMENT_LAYER_MAX_VALUE = 2147483647,
} GhosttyKittyPlacementLayer;

typedef enum {
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_ITERATOR_OPTION_LAYER = 0,
  GHOSTTY_KITTY_GRAPHICS_PLACEMENT_ITERATOR_OPTION_MAX_VALUE = 2147483647,
} GhosttyKittyGraphicsPlacementIteratorOption;

typedef enum {
  GHOSTTY_KITTY_IMAGE_FORMAT_RGB = 0,
  GHOSTTY_KITTY_IMAGE_FORMAT_RGBA = 1,
  GHOSTTY_KITTY_IMAGE_FORMAT_PNG = 2,
  GHOSTTY_KITTY_IMAGE_FORMAT_GRAY_ALPHA = 3,
  GHOSTTY_KITTY_IMAGE_FORMAT_GRAY = 4,
  GHOSTTY_KITTY_IMAGE_FORMAT_MAX_VALUE = 2147483647,
} GhosttyKittyImageFormat;

typedef enum {
  GHOSTTY_KITTY_IMAGE_COMPRESSION_NONE = 0,
  GHOSTTY_KITTY_IMAGE_COMPRESSION_ZLIB_DEFLATE = 1,
  GHOSTTY_KITTY_IMAGE_COMPRESSION_MAX_VALUE = 2147483647,
} GhosttyKittyImageCompression;

typedef enum {
  GHOSTTY_KITTY_IMAGE_DATA_INVALID = 0,
  GHOSTTY_KITTY_IMAGE_DATA_ID = 1,
  GHOSTTY_KITTY_IMAGE_DATA_NUMBER = 2,
  GHOSTTY_KITTY_IMAGE_DATA_WIDTH = 3,
  GHOSTTY_KITTY_IMAGE_DATA_HEIGHT = 4,
  GHOSTTY_KITTY_IMAGE_DATA_FORMAT = 5,
  GHOSTTY_KITTY_IMAGE_DATA_COMPRESSION = 6,
  GHOSTTY_KITTY_IMAGE_DATA_DATA_PTR = 7,
  GHOSTTY_KITTY_IMAGE_DATA_DATA_LEN = 8,
  GHOSTTY_KITTY_IMAGE_DATA_GENERATION = 9,
  GHOSTTY_KITTY_IMAGE_DATA_MAX_VALUE = 2147483647,
} GhosttyKittyGraphicsImageData;

typedef struct {
  size_t size;
  uint32_t pixel_width;
  uint32_t pixel_height;
  uint32_t grid_cols;
  uint32_t grid_rows;
  int32_t viewport_col;
  int32_t viewport_row;
  bool viewport_visible;
  uint32_t source_x;
  uint32_t source_y;
  uint32_t source_width;
  uint32_t source_height;
} GhosttyKittyGraphicsPlacementRenderInfo;

GhosttyResult ghostty_kitty_graphics_get(GhosttyKittyGraphics graphics,
                                         GhosttyKittyGraphicsData data,
                                         void* out);
GhosttyKittyGraphicsImage ghostty_kitty_graphics_image(GhosttyKittyGraphics graphics,
                                                       uint32_t image_id);
GhosttyResult ghostty_kitty_graphics_image_get(GhosttyKittyGraphicsImage image,
                                               GhosttyKittyGraphicsImageData data,
                                               void* out);
GhosttyResult ghostty_kitty_graphics_placement_iterator_new(
    const GhosttyAllocator* allocator,
    GhosttyKittyGraphicsPlacementIterator* out_iterator);
void ghostty_kitty_graphics_placement_iterator_free(GhosttyKittyGraphicsPlacementIterator iterator);
GhosttyResult ghostty_kitty_graphics_placement_iterator_set(
    GhosttyKittyGraphicsPlacementIterator iterator,
    GhosttyKittyGraphicsPlacementIteratorOption option,
    const void* value);
bool ghostty_kitty_graphics_placement_next(GhosttyKittyGraphicsPlacementIterator iterator);
GhosttyResult ghostty_kitty_graphics_placement_get(
    GhosttyKittyGraphicsPlacementIterator iterator,
    GhosttyKittyGraphicsPlacementData data,
    void* out);
GhosttyResult ghostty_kitty_graphics_placement_render_info(
    GhosttyKittyGraphicsPlacementIterator iterator,
    GhosttyKittyGraphicsImage image,
    GhosttyTerminal terminal,
    GhosttyKittyGraphicsPlacementRenderInfo* out_info);
GhosttyResult ghostty_kitty_graphics_placement_pixel_size(
    GhosttyKittyGraphicsPlacementIterator iterator,
    GhosttyKittyGraphicsImage image,
    GhosttyTerminal terminal,
    uint32_t* out_width,
    uint32_t* out_height);
GhosttyResult ghostty_kitty_graphics_placement_grid_size(
    GhosttyKittyGraphicsPlacementIterator iterator,
    GhosttyKittyGraphicsImage image,
    GhosttyTerminal terminal,
    uint32_t* out_cols,
    uint32_t* out_rows);
GhosttyResult ghostty_kitty_graphics_placement_viewport_pos(
    GhosttyKittyGraphicsPlacementIterator iterator,
    GhosttyKittyGraphicsImage image,
    GhosttyTerminal terminal,
    int32_t* out_col,
    int32_t* out_row);

typedef struct {
    uint32_t width;
    uint32_t height;
    uint8_t* data;
    size_t data_len;
} GhosttySysImage;
typedef bool (*GhosttySysDecodePngFn)(void* userdata,
                                      const GhosttyAllocator* allocator,
                                      const uint8_t* data,
                                      size_t data_len,
                                      GhosttySysImage* out);
typedef enum {
    GHOSTTY_SYS_OPT_USERDATA = 0,
    GHOSTTY_SYS_OPT_DECODE_PNG = 1,
    GHOSTTY_SYS_OPT_LOG = 2,
    GHOSTTY_SYS_OPT_MAX_VALUE = 2147483647,
} GhosttySysOption;
GhosttyResult ghostty_sys_set(GhosttySysOption option, const void* value);

typedef struct {
  uint16_t x;
  uint32_t y;
} GhosttyPointCoordinate;
typedef enum {
  GHOSTTY_POINT_TAG_ACTIVE = 0,
  GHOSTTY_POINT_TAG_VIEWPORT = 1,
  GHOSTTY_POINT_TAG_SCREEN = 2,
  GHOSTTY_POINT_TAG_HISTORY = 3,
  GHOSTTY_POINT_TAG_MAX_VALUE = 2147483647,
} GhosttyPointTag;
typedef union {
  GhosttyPointCoordinate coordinate;
  uint64_t _padding[2];
} GhosttyPointValue;
typedef struct {
  GhosttyPointTag tag;
  GhosttyPointValue value;
} GhosttyPoint;
GhosttyResult ghostty_terminal_grid_ref(GhosttyTerminal terminal,
                                        GhosttyPoint point,
                                        GhosttyGridRef *out_ref);
