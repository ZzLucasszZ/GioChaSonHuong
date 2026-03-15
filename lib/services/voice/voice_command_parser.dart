import '../../core/utils/vietnamese_utils.dart';
import 'voice_command.dart';

/// Parses raw Vietnamese speech text into structured [VoiceCommand].
///
/// Uses pattern matching with normalized (no-diacritics) text for
/// robust matching against Vietnamese speech recognition output.
///
/// Long natural sentences are supported by:
/// 1. Stripping filler words ("tôi muốn", "đi", "nào", etc.)
/// 2. Checking specific action patterns BEFORE generic navigation
/// 3. Handling "nhà hàng", "sản phẩm" etc. in prefix extraction
class VoiceCommandParser {
  /// Parse raw text from speech recognition into a VoiceCommand.
  VoiceCommand parse(String rawText, {double confidence = 1.0}) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return VoiceCommand(
        intent: VoiceIntent.unknown,
        rawText: text,
        confidence: confidence,
      );
    }

    // Pre-process: strip filler words for better matching
    final (normalized, cleanRaw) = _preprocess(text);

    // Specific actions first, then generic navigation last.
    // This prevents "xem công nợ nhà hàng X" matching navigateDebt
    // instead of viewDebt(restaurant=X).
    return _trySearch(normalized, cleanRaw, confidence)
        ?? _tryOrderActions(normalized, cleanRaw, confidence)
        ?? _tryInventoryActions(normalized, cleanRaw, confidence)
        ?? _tryDeliveryActions(normalized, cleanRaw, confidence)
        ?? _tryDebtActions(normalized, cleanRaw, confidence)
        ?? _tryRentalActions(normalized, cleanRaw, confidence)
        ?? _tryUtility(normalized, cleanRaw, confidence)
        ?? _tryNavigation(normalized, cleanRaw, confidence)
        ?? VoiceCommand(
            intent: VoiceIntent.unknown,
            rawText: text, // Keep original for unknown
            confidence: confidence,
          );
  }

  // ─── PRE-PROCESSING ───────────────────────────────────────

  /// Strip common Vietnamese filler words from both normalized and raw text.
  /// Returns (normalizedClean, rawClean).
  ///
  /// Example: "tôi muốn tạo đơn hàng cho nhà hàng Yến Lan đi"
  ///       → ("tao don hang cho nha hang yen lan", "tạo đơn hàng cho nhà hàng Yến Lan")
  (String, String) _preprocess(String rawText) {
    var normalized = normalizeForSearch(rawText);
    var raw = rawText.trim();

    // Fix common Vietnamese STT misrecognitions (on normalized text)
    normalized = _correctSttErrors(normalized);

    // Leading filler phrases (normalized form, longest first)
    const leadingFillers = [
      'tom oi giup toi ', 'tom oi cho toi ', 'hi tom giup toi ',
      'tom oi lam on ', 'hi tom cho toi ', 'hi tom lam on ',
      'giup toi ', 'cho toi ', 'lam on ', 'vui long ',
      'toi muon ', 'em muon ', 'anh muon ', 'minh muon ', 'toi can ',
      'hay ', 'di ',
      'tom oi ', 'hi tom ', 'tom ',
    ];

    for (final filler in leadingFillers) {
      if (normalized.startsWith(filler)) {
        final wordCount = filler.trim().split(RegExp(r'\s+')).length;
        normalized = normalized.substring(filler.length);
        final rawWords = raw.split(RegExp(r'\s+'));
        if (rawWords.length > wordCount) {
          raw = rawWords.sublist(wordCount).join(' ');
        }
        break; // Only strip one leading filler
      }
    }

    // Trailing filler words (normalized form, longest first)
    const trailingFillers = [
      ' giup toi', ' cho toi', ' duoc khong',
      ' ngay bay gio', ' ngay', ' luon', ' lien',
      ' di', ' nao', ' nhe', ' ha', ' oi', ' xong',
    ];

    for (final filler in trailingFillers) {
      if (normalized.endsWith(filler)) {
        final wordCount = filler.trim().split(RegExp(r'\s+')).length;
        normalized = normalized
            .substring(0, normalized.length - filler.length)
            .trim();
        final rawWords = raw.split(RegExp(r'\s+'));
        if (rawWords.length > wordCount) {
          raw = rawWords.sublist(0, rawWords.length - wordCount).join(' ');
        }
        break; // Only strip one trailing filler
      }
    }

    return (normalized, raw);
  }

  // ─── NAVIGATION ───────────────────────────────────────────

  VoiceCommand? _tryNavigation(String n, String raw, double c) {
    // Order tab
    if (_matchesAny(n, [
      'don hang', 'mo don hang', 'tab don hang', 'mo dat hang',
      'xem don hang', 'vao don hang', 'cho xem don hang',
      'danh sach don hang', 'danh sach nha hang', 'quan ly don hang',
      'quay lai don hang', 'tro ve don hang',
      'mo nha hang', 'xem nha hang',
    ])) {
      return VoiceCommand(intent: VoiceIntent.navigateOrders, rawText: raw, confidence: c);
    }

    // Inventory tab
    if (_matchesAny(n, [
      'kho', 'ton kho', 'mo kho', 'tab kho', 'mo ton kho', 'xem kho',
      'vao kho', 'cho xem kho', 'quan ly kho', 'hang ton kho',
      'xem hang ton', 'quay lai kho', 'tro ve kho',
    ])) {
      return VoiceCommand(intent: VoiceIntent.navigateInventory, rawText: raw, confidence: c);
    }

    // Debt tab
    if (_matchesAny(n, [
      'cong no', 'mo cong no', 'tab cong no', 'xem cong no',
      'vao cong no', 'cho xem cong no', 'quan ly cong no',
      'danh sach no', 'quay lai cong no', 'tro ve cong no',
      'kiem tra no', 'kiem tra cong no', 'so no',
    ])) {
      return VoiceCommand(intent: VoiceIntent.navigateDebt, rawText: raw, confidence: c);
    }

    // Delivery tab
    if (_matchesAny(n, [
      'giao hang', 'mo giao hang', 'tab giao hang', 'giao',
      'xem giao hang', 'vao giao hang', 'cho xem giao hang',
      'don giao', 'quan ly giao hang', 'danh sach giao',
      'quay lai giao hang', 'tro ve giao hang',
    ])) {
      return VoiceCommand(intent: VoiceIntent.navigateDelivery, rawText: raw, confidence: c);
    }

    // Rental tab
    if (_matchesAny(n, [
      'nha thue', 'cho thue', 'mo nha thue', 'tab thue', 'thue',
      'xem nha thue', 'vao nha thue', 'phong thue', 'cho xem nha thue',
      'quan ly thue', 'danh sach khach thue', 'quay lai thue',
      'tro ve thue', 'quan ly phong', 'xem khach thue',
    ])) {
      return VoiceCommand(intent: VoiceIntent.navigateRental, rawText: raw, confidence: c);
    }

    // Products tab
    if (_matchesAny(n, [
      'san pham', 'mo san pham', 'tab san pham', 'quan ly san pham',
      'xem san pham', 'vao san pham', 'cho xem san pham',
      'danh sach san pham', 'quay lai san pham', 'tro ve san pham',
    ])) {
      return VoiceCommand(intent: VoiceIntent.navigateProducts, rawText: raw, confidence: c);
    }

    return null;
  }

  // ─── SEARCH ───────────────────────────────────────────────

  VoiceCommand? _trySearch(String n, String raw, double c) {
    // "tìm nhà hàng X" / "tìm X"
    String? param;

    param = _extractParam(n, [
      'tim kiem nha hang ', 'kiem tra nha hang ', 'tim nha hang ',
    ]);
    if (param != null) {
      return VoiceCommand(
        intent: VoiceIntent.searchRestaurant,
        params: {'value': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // "tìm sản phẩm X"
    param = _extractParam(n, [
      'tim kiem san pham ', 'kiem tra san pham ', 'tim san pham ',
    ]);
    if (param != null) {
      return VoiceCommand(
        intent: VoiceIntent.searchProduct,
        params: {'value': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // "tìm công nợ X" / "tìm nợ X"
    param = _extractParam(n, [
      'tim kiem cong no ', 'tim cong no ', 'tim no ',
    ]);
    if (param != null) {
      return VoiceCommand(
        intent: VoiceIntent.searchDebt,
        params: {'value': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // "tìm khách thuê X" / "tìm phòng X"
    param = _extractParam(n, [
      'tim khach thue ', 'tim nguoi thue ', 'kiem tra phong ', 'tim phong ',
    ]);
    if (param != null) {
      return VoiceCommand(
        intent: VoiceIntent.searchTenant,
        params: {'value': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // Generic "tìm X" → default to restaurant search
    param = _extractParam(n, ['tim kiem ', 'tim ']);
    if (param != null && param.isNotEmpty) {
      return VoiceCommand(
        intent: VoiceIntent.searchRestaurant,
        params: {'value': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    return null;
  }

  // ─── ORDER ACTIONS ────────────────────────────────────────

  VoiceCommand? _tryOrderActions(String n, String raw, double c) {
    String? param;

    // "mở nhà hàng X" / "xem nhà hàng X" → view restaurant detail
    param = _extractParam(n, [
      'xem chi tiet nha hang ', 'chi tiet nha hang ',
      'mo nha hang ', 'xem nha hang ',
      'vao nha hang ', 'chon nha hang ',
    ]);
    if (param != null && param.isNotEmpty) {
      if (_isModifier(param)) {
        return VoiceCommand(intent: VoiceIntent.viewRestaurant, rawText: raw, confidence: c);
      }
      return VoiceCommand(
        intent: VoiceIntent.viewRestaurant,
        params: {'restaurant': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // "tạo đơn cho [nhà hàng] X" / "đặt hàng cho [nhà hàng] X"
    // Longer prefixes (with "nhà hàng") MUST come before shorter ones
    param = _extractParam(n, [
      'tao don hang moi cho nha hang ', 'them don hang moi cho nha hang ',
      'tao don hang cho nha hang ', 'them don hang cho nha hang ',
      'dat hang cho nha hang ', 'tao don cho nha hang ',
      'them don cho nha hang ', 'dat hang nha hang ',
      'tao don hang nha hang ', 'tao don nha hang ',
      'them don moi cho nha hang ', 'don moi cho nha hang ',
      'dat them cho nha hang ', 'them don moi cho ',
      'tao don hang cho ', 'them don hang cho ',
      'tao don cho ', 'dat hang cho ',
      'them don cho ', 'don moi cho ',
      'dat them cho ',
      'tao don hang ', 'them don hang ', 'dat hang ',
    ]);
    if (param != null && param.isNotEmpty) {
      if (_isModifier(param)) {
        return VoiceCommand(intent: VoiceIntent.createOrder, rawText: raw, confidence: c);
      }
      return VoiceCommand(
        intent: VoiceIntent.createOrder,
        params: {'restaurant': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // "đơn hôm nay"
    if (_matchesAny(n, [
      'don hom nay', 'xem don hom nay', 'don hang hom nay',
      'don ngay hom nay', 'hom nay co don gi', 'hom nay don gi',
    ])) {
      return VoiceCommand(intent: VoiceIntent.viewTodayOrders, rawText: raw, confidence: c);
    }

    // "tạo nhà hàng" / "thêm nhà hàng"
    if (_matchesAny(n, [
      'tao nha hang', 'them nha hang', 'nha hang moi',
      'them nha hang moi', 'dang ky nha hang', 'tao nha hang moi',
      'tao quan', 'them quan moi',
    ])) {
      return VoiceCommand(intent: VoiceIntent.createRestaurant, rawText: raw, confidence: c);
    }

    // Generic "tạo đơn" / "thêm đơn" / "đặt hàng" without restaurant name
    if (_matchesAny(n, [
      'tao don hang', 'tao don moi', 'tao don',
      'them don hang', 'them don moi', 'them don',
      'dat hang', 'dat don', 'dat don moi',
    ])) {
      return VoiceCommand(intent: VoiceIntent.createOrder, rawText: raw, confidence: c);
    }

    return null;
  }

  // ─── INVENTORY ACTIONS ────────────────────────────────────

  VoiceCommand? _tryInventoryActions(String n, String raw, double c) {
    // "lịch sử kho" / "lịch sử nhập kho" (check before generic "nhập kho")
    if (_matchesAny(n, [
      'lich su kho', 'lich su nhap kho', 'xem lich su kho',
      'xem lich su nhap kho', 'lich su ton kho', 'lich su nhap',
      'xem lich su nhap', 'xem lich su',
    ])) {
      return VoiceCommand(intent: VoiceIntent.viewStockHistory, rawText: raw, confidence: c);
    }

    // "nhập kho [sản phẩm] X" — longer prefix first
    final param = _extractParam(n, [
      'nhap kho san pham ', 'nhap hang san pham ',
      'them vao kho san pham ', 'bo sung kho san pham ',
      'nhap kho ', 'nhap hang ', 'them vao kho ', 'bo sung kho ',
    ]);
    if (param != null && param.isNotEmpty) {
      if (_isModifier(param)) {
        return VoiceCommand(intent: VoiceIntent.stockIn, rawText: raw, confidence: c);
      }
      return VoiceCommand(
        intent: VoiceIntent.stockIn,
        params: {'product': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // "nhập kho" (no product specified)
    if (_matchesAny(n, [
      'nhap kho', 'nhap hang', 'them hang vao kho',
      'bo sung kho', 'nhap them hang',
    ])) {
      return VoiceCommand(intent: VoiceIntent.stockIn, rawText: raw, confidence: c);
    }

    // "xem tồn kho"
    if (_matchesAny(n, [
      'xem ton kho', 'xem ton', 'kiem tra kho', 'kiem tra ton kho',
      'con bao nhieu hang', 'so luong ton', 'hang con lai',
    ])) {
      return VoiceCommand(intent: VoiceIntent.viewStock, rawText: raw, confidence: c);
    }

    return null;
  }

  // ─── DELIVERY ACTIONS ─────────────────────────────────────

  VoiceCommand? _tryDeliveryActions(String n, String raw, double c) {
    // "chia sẻ giao hàng" (check before generic delivery patterns)
    if (_matchesAny(n, [
      'chia se giao hang', 'share giao hang', 'gui giao hang',
      'chia se don giao', 'gui don giao', 'share don giao',
      'gui danh sach giao',
    ])) {
      return VoiceCommand(intent: VoiceIntent.shareDelivery, rawText: raw, confidence: c);
    }

    // "giao tất cả" / "giao hết"
    if (_matchesAny(n, [
      'giao tat ca', 'giao het', 'giao het di', 'giao tat',
      'xac nhan giao tat ca', 'xac nhan giao het',
      'giao tat ca don', 'da giao het', 'giao het don',
    ])) {
      return VoiceCommand(intent: VoiceIntent.deliverAll, rawText: raw, confidence: c);
    }

    if (_matchesAny(n, [
      'giao hom nay', 'xem giao hom nay', 'don giao hom nay',
      'giao hang hom nay', 'hom nay giao gi', 'giao nhung gi',
      'don can giao', 'don chua giao', 'can giao hom nay',
      'danh sach giao hom nay', 'hom nay can giao gi',
    ])) {
      return VoiceCommand(intent: VoiceIntent.viewTodayDelivery, rawText: raw, confidence: c);
    }
    return null;
  }

  // ─── DEBT ACTIONS ─────────────────────────────────────────

  VoiceCommand? _tryDebtActions(String n, String raw, double c) {
    // "thanh toán cho [nhà hàng] X" / "trả nợ cho [nhà hàng] X"
    // Longer prefixes (with "nhà hàng" / "công nợ") first
    String? param;

    param = _extractParam(n, [
      'thanh toan het cho nha hang ', 'thanh toan tat ca cho nha hang ',
      'tra het no cho nha hang ', 'tra het no nha hang ',
      'thanh toan cong no cho nha hang ', 'thanh toan cong no nha hang ',
      'thanh toan cho nha hang ', 'tra no cho nha hang ',
      'tra tien cho nha hang ', 'tra no nha hang ',
      'thanh toan nha hang ', 'tra tien nha hang ',
      'thanh toan cong no cho ', 'thanh toan cong no ',
      'thanh toan cho ', 'tra no cho ',
      'tra tien cho ', 'tra het cho ',
      'thanh toan ', 'tra no ', 'tra tien ',
    ]);
    if (param != null && param.isNotEmpty) {
      if (_isModifier(param)) {
        return VoiceCommand(intent: VoiceIntent.payDebt, rawText: raw, confidence: c);
      }
      return VoiceCommand(
        intent: VoiceIntent.payDebt,
        params: {'restaurant': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // "thêm nợ cũ"
    if (_matchesAny(n, [
      'them no cu', 'no cu', 'ghi no cu', 'them cong no cu',
      'ghi nhan no', 'them no', 'ghi no', 'no truoc day',
    ])) {
      return VoiceCommand(intent: VoiceIntent.addLegacyDebt, rawText: raw, confidence: c);
    }

    // "công nợ [nhà hàng] X" — longer prefixes first
    param = _extractParam(n, [
      'xem cong no cua nha hang ', 'xem cong no nha hang ',
      'cong no cua nha hang ', 'cong no nha hang ',
      'kiem tra cong no nha hang ', 'kiem tra no nha hang ',
      'cong no cua ', 'no cua ', 'kiem tra cong no ',
      'kiem tra no ', 'so no ',
    ]);
    if (param != null && param.isNotEmpty) {
      if (_isModifier(param)) {
        return VoiceCommand(intent: VoiceIntent.viewDebt, rawText: raw, confidence: c);
      }
      return VoiceCommand(
        intent: VoiceIntent.viewDebt,
        params: {'restaurant': _extractOriginalParam(raw, param)},
        rawText: raw,
        confidence: c,
      );
    }

    // Generic "thanh toán" / "trả nợ" (without restaurant)
    // Use exact match for short ambiguous patterns to prevent false hits
    // (e.g., "kiểm tra nợ" contains "tra nợ" but means viewDebt)
    if (n == 'tra no' || n == 'tra tien' ||
        _matchesAny(n, [
          'thanh toan', 'thanh toan cong no', 'tra het',
          'thanh toan het', 'thanh toan tat ca',
        ])) {
      return VoiceCommand(intent: VoiceIntent.payDebt, rawText: raw, confidence: c);
    }

    return null;
  }

  // ─── RENTAL ACTIONS ───────────────────────────────────────

  VoiceCommand? _tryRentalActions(String n, String raw, double c) {
    // "thêm khách thuê"
    if (_matchesAny(n, [
      'them khach thue', 'them nguoi thue', 'khach thue moi',
      'them phong thue', 'them nguoi o', 'them khach moi',
      'nguoi thue moi', 'them phong moi', 'dang ky khach thue',
    ])) {
      return VoiceCommand(intent: VoiceIntent.addTenant, rawText: raw, confidence: c);
    }

    // "tạo hóa đơn [cho] phòng X"
    String? param;

    param = _extractParam(n, [
      'tao hoa don cho phong ', 'lap hoa don cho phong ',
      'tao hoa don phong ', 'hoa don phong ',
      'lap hoa don phong ', 'hoa don cho phong ',
      'tinh tien phong ', 'thu tien phong ',
      'tinh tien nha thue phong ', 'thu tien nha phong ',
    ]);
    if (param != null && param.trim().isNotEmpty) {
      if (_isModifier(param.trim())) {
        return VoiceCommand(intent: VoiceIntent.createInvoice, rawText: raw, confidence: c);
      }
      return VoiceCommand(
        intent: VoiceIntent.createInvoice,
        params: {'room': param.trim()},
        rawText: raw,
        confidence: c,
      );
    }

    // Generic "tạo hóa đơn" (no room specified)
    if (_matchesAny(n, [
      'tao hoa don', 'lap hoa don', 'tinh tien nha',
      'thu tien nha', 'tinh tien phong', 'thu tien phong',
    ])) {
      return VoiceCommand(intent: VoiceIntent.createInvoice, rawText: raw, confidence: c);
    }

    // "chốt sổ phòng X" / "nhập điện nước phòng X"
    param = _extractParam(n, [
      'nhap so dien nuoc phong ', 'nhap dien nuoc phong ',
      'chot so phong ', 'chot so dong ho phong ',
      'chot dong ho phong ', 'nhap dong ho phong ',
      'cap nhat dien nuoc phong ', 'nhap chi so phong ',
    ]);
    if (param != null && param.trim().isNotEmpty) {
      return VoiceCommand(
        intent: VoiceIntent.enterMeterReading,
        params: {'room': param.trim()},
        rawText: raw,
        confidence: c,
      );
    }
    if (_matchesAny(n, [
      'nhap so dien nuoc', 'nhap dien nuoc', 'chot so',
      'chot dong ho', 'nhap dong ho', 'cap nhat dien nuoc',
      'chot so dong ho', 'nhap chi so dong ho',
    ])) {
      return VoiceCommand(intent: VoiceIntent.enterMeterReading, rawText: raw, confidence: c);
    }

    // "thu tiền nhà phòng X"
    param = _extractParam(n, [
      'thu tien nha phong ', 'thu tien thue phong ',
      'nhan tien nha phong ', 'thu no phong ',
      'thanh toan tien nha phong ',
    ]);
    if (param != null && param.trim().isNotEmpty) {
      return VoiceCommand(
        intent: VoiceIntent.markRentPaid,
        params: {'room': param.trim()},
        rawText: raw,
        confidence: c,
      );
    }

    // "chia sẻ hóa đơn phòng X"
    param = _extractParam(n, [
      'chia se hoa don phong ', 'share hoa don phong ',
      'gui hoa don phong ', 'xuat hoa don phong ',
      'chia se tien phong ',
    ]);
    if (param != null && param.trim().isNotEmpty) {
      return VoiceCommand(
        intent: VoiceIntent.shareTenantInvoices,
        params: {'room': param.trim()},
        rawText: raw,
        confidence: c,
      );
    }
    if (_matchesAny(n, [
      'chia se hoa don thue', 'chia se hoa don nha thue',
      'gui hoa don thue', 'xuat hoa don thue',
    ])) {
      return VoiceCommand(intent: VoiceIntent.shareTenantInvoices, rawText: raw, confidence: c);
    }

    // "phòng X" / "xem phòng X"
    param = _extractParam(n, [
      'chi tiet phong ', 'thong tin phong ',
      'xem khach thue phong ', 'xem phong ', 'phong ',
    ]);
    if (param != null && param.trim().isNotEmpty) {
      if (_isModifier(param.trim())) {
        return VoiceCommand(intent: VoiceIntent.viewRoom, rawText: raw, confidence: c);
      }
      return VoiceCommand(
        intent: VoiceIntent.viewRoom,
        params: {'room': param.trim()},
        rawText: raw,
        confidence: c,
      );
    }

    return null;
  }

  // ─── UTILITY ──────────────────────────────────────────────

  VoiceCommand? _tryUtility(String n, String raw, double c) {
    // "thêm sản phẩm"
    if (_matchesAny(n, [
      'them san pham', 'san pham moi', 'tao san pham', 'them sp',
      'them san pham moi', 'tao mat hang', 'them mat hang',
      'them sp moi', 'dang ky san pham',
    ])) {
      return VoiceCommand(intent: VoiceIntent.addProduct, rawText: raw, confidence: c);
    }

    if (_matchesAny(n, [
      'sao luu', 'backup', 'mo sao luu', 'tao ban sao luu',
      'sao luu du lieu', 'backup du lieu', 'sao luu ngay',
      'khoi phuc', 'khoi phuc du lieu', 'xuat file', 'xuat json',
      'nhap file', 'nhap json', 'phuc hoi du lieu',
    ])) {
      return VoiceCommand(intent: VoiceIntent.openBackup, rawText: raw, confidence: c);
    }

    if (_matchesAny(n, [
      'huong dan', 'tro giup', 'help', 'mo huong dan',
      'huong dan su dung', 'giup do', 'can giup',
      'xem huong dan', 'doc huong dan', 'cach su dung',
      'su dung nhu nao', 'cach dung',
    ])) {
      return VoiceCommand(intent: VoiceIntent.openHelp, rawText: raw, confidence: c);
    }

    return null;
  }

  // ─── HELPERS ──────────────────────────────────────────────

  /// Fix common Vietnamese STT misrecognitions on normalized
  /// (diacritics-removed) text. Targeted phrase-level corrections
  /// that are unambiguous in this app's context.
  static String _correctSttErrors(String normalized) {
    var text = normalized;
    const corrections = <String, String>{
      // "hàng" misheard as "hành" (very common)
      'don hanh': 'don hang',
      'dat hanh': 'dat hang',
      'nha hanh': 'nha hang',
      'giao hanh': 'giao hang',
      'nhap hanh': 'nhap hang',
      'ton hanh': 'ton hang',
      // "đơn" misheard as "đội"/"đồi"
      'doi hang': 'don hang',
      'doi hanh': 'don hang',
      // "sản" misheard as "sáng"
      'sang pham': 'san pham',
      // "nợ" misheard as "nợi"/"nới"
      'cong noi': 'cong no',
      // "tồn" misheard as "tôm"/"tom"
      'tom kho': 'ton kho',
      // "hóa đơn" misheard as "hóa đội"
      'hoa doi': 'hoa don',
      // "thanh toán" misheard as "than toán"
      'than toan': 'thanh toan',
      // "khách" misheard as "khác"
      'khac thue': 'khach thue',
    };
    for (final entry in corrections.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text;
  }

  /// Common Vietnamese modifier/filler words that should NOT be treated
  /// as entity names (restaurant, product, room number) when extracted
  /// from short catch-all prefixes like "tạo đơn hàng [X]".
  static const _modifiers = {
    'moi', 'cu', 'nay', 'het', 'ngay', 'nhanh', 'luon', 'lien', 'di',
    'them', 'nua', 'lai', 'tat ca', 'toan bo', 'xong', 'duoc', 'roi',
    'sang', 'chieu', 'hom nay', 'hom qua', 'ngay mai', 'toi',
  };

  /// Returns true if [param] is only a modifier word (not a real entity name).
  /// E.g. "moi" from "tạo đơn hàng mới" should not be treated as a restaurant.
  bool _isModifier(String param) {
    return _modifiers.contains(param.trim());
  }

  /// Check if normalized text matches any of the patterns.
  /// Uses contains for flexible matching (handles extra words like "đi", "nào").
  bool _matchesAny(String normalized, List<String> patterns) {
    return patterns.any((p) => normalized == p || normalized.contains(p));
  }

  /// Try to extract a parameter after a prefix match.
  /// Returns the remaining text after the prefix, or null if no match.
  String? _extractParam(String normalized, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        return normalized.substring(prefix.length).trim();
      }
    }
    return null;
  }

  /// Given a normalized param and the raw text, try to extract
  /// the original Vietnamese text (with diacritics) for the param portion.
  String _extractOriginalParam(String rawText, String normalizedParam) {
    // The param is at the end of the raw text, same word count
    final paramWords = normalizedParam.split(RegExp(r'\s+')).length;
    final rawWords = rawText.trim().split(RegExp(r'\s+'));

    if (paramWords >= rawWords.length) return rawText.trim();

    return rawWords.sublist(rawWords.length - paramWords).join(' ');
  }
}
