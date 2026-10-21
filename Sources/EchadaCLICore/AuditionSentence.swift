import Foundation

/// Raised when no curated audition sentence exists for a requested language.
enum AuditionSentenceError: LocalizedError {
  case unsupportedLanguage(String, supported: [String])

  var errorDescription: String? {
    switch self {
    case .unsupportedLanguage(let language, let supported):
      return """
        No voice-audition sentence is available for language '\(language)'. \
        Supported languages: \(supported.joined(separator: ", ")). \
        These are the languages the TTS model itself supports; to add another, \
        add its sentences to AuditionSentence.pools.
        """
    }
  }
}

/// Supplies the short, in-language sentence spoken during a voice audition.
///
/// The audition audio doubles as the **voice-lock reference** the `.vox`
/// embedding is derived from, so this text is not cosmetic — it is part of the
/// artifact's identity.
///
/// ## Why these are curated rather than generated
///
/// echada previously sourced every audition sentence from Apple's on-device
/// Foundation Model. That was replaced because generation is the wrong tool for
/// this job on three counts:
///
/// 1. **Reliability.** The system model fails requests transiently and, more
///    awkwardly, sometimes returns a fluent sentence in the *wrong language*.
///    Neither is detectable without a second check, and both aborted real cast
///    runs. A bounded retry helped but could not eliminate it.
/// 2. **Reproducibility.** Because the audition audio is the voice-lock
///    reference, non-deterministic reference text meant the *same* `voicePrompt`
///    produced a *different* `.vox` embedding on every run, with no record of
///    what text produced which voice. Curated text makes `.vox` generation
///    deterministic.
/// 3. **Portability.** Generation required Apple Intelligence to be enabled,
///    which made `echada generate vox` unavailable on CI and on any Mac without
///    it — despite the TTS pipeline itself having no such requirement.
///
/// A language model adds no value here: the requirement is a fixed, neutral,
/// phonetically varied utterance per language, which is exactly what the speech
/// field has always solved with curated reading passages.
///
/// ## Coverage
///
/// Every language in `pools` is one the TTS model supports (`TTSLanguage`), and
/// every language the TTS model supports has sentences here — so this is total
/// coverage of what can actually be synthesized, not a subset.
///
/// ## Sentence contract
///
/// Each sentence is natural, neutral, free of proper names (the English reading
/// passages keep the few their published text carries), and free of
/// quotation marks, ellipses, em dashes, and stacked punctuation (all of which
/// destabilize Qwen3-TTS speaker conditioning). Word choice favours a broad
/// spread of that language's consonant and vowel sounds so the audition surfaces
/// how a voice renders fricatives, plosives, nasals, and diphthongs.
/// `AuditionSentenceTests` enforces the contract against the data.
enum AuditionSentence {

  /// Curated audition sentences, keyed by ISO 639-1 code.
  ///
  /// The first entry of each pool is the canonical sentence, returned when no
  /// character is given. Cast generation rotates through the pool per character
  /// (see ``auditionSentence(language:character:variant:)``).
  static let pools: [String: [String]] = [
    // English draws on the three standard speech-science reading passages, two
    // selections each: The North Wind and the Sun (the IPA's reference passage),
    // the Rainbow Passage (Fairbanks), and Please Call Stella (Speech Accent
    // Archive, built to surface accent). Longer than the other pools on purpose:
    // a ~12-15 second reference gives the clone embedding more to lock onto.
    "en": [
      "The North Wind and the Sun were disputing which was the stronger, when a traveler came along wrapped in a warm cloak. They agreed that the one who first succeeded in making the traveler take his cloak off should be considered stronger than the other.",
      "When the sunlight strikes raindrops in the air, they act as a prism and form a rainbow. The rainbow is a division of white light into many beautiful colors. These take the shape of a long round arch, with its path high above, and its two ends apparently beyond the horizon.",
      "Please call Stella. Ask her to bring these things with her from the store: six spoons of fresh snow peas, five thick slabs of blue cheese, and maybe a snack for her brother Bob.",
      "Then the North Wind blew as hard as he could, but the more he blew the more closely did the traveler fold his cloak around him, and at last the North Wind gave up the attempt. Then the Sun shined out warmly, and immediately the traveler took off his cloak.",
      "There is, according to legend, a boiling pot of gold at one end. People look, but no one ever finds it. When a man looks for something beyond his reach, his friends say he is looking for the pot of gold at the end of the rainbow.",
      "We also need a small plastic snake and a big toy frog for the kids. She can scoop these things into three red bags, and we will go meet her Wednesday at the train station.",
    ],
    "es": [
      "La brisa fresca del amanecer recorría el jardín mientras los pájaros cantaban entre las ramas del viejo naranjo.",
      "Cada verano recogemos aceitunas maduras, charlamos bajo la sombra y compartimos pan reciente con queso del pueblo.",
      "El pequeño barco cruzó la bahía tranquila justo cuando la luz dorada tocaba los tejados de la ciudad.",
    ],
    "fr": [
      "La brume légère glissait sur la rivière tandis que les cloches du village sonnaient doucement dans le matin.",
      "Chaque automne nous ramassons des pommes mûres, préparons une tarte chaude et partageons un cidre près du feu.",
      "Le vieux libraire rangeait ses ouvrages poussiéreux en fredonnant un air joyeux appris dans sa jeunesse lointaine.",
    ],
    "it": [
      "La luce dorata del tramonto scivolava sui tetti mentre le rondini volavano sopra la piazza silenziosa del paese.",
      "Ogni estate raccogliamo pomodori maturi e prepariamo una salsa profumata che conserviamo per i lunghi mesi freddi.",
      "Il vecchio pescatore riparava le sue reti canticchiando una melodia lenta imparata molti anni prima dal nonno.",
    ],
    "pt": [
      "A brisa morna atravessava o jardim enquanto os pássaros cantavam entre os galhos da velha figueira florida.",
      "Todos os invernos preparamos uma sopa espessa, acendemos a lareira e conversamos até a noite ficar silenciosa.",
      "O pequeno barco cruzou a baía calma justo quando a luz dourada tocava os telhados antigos da cidade.",
    ],
    "de": [
      "Der kühle Morgennebel zog über den Fluss, während die Glocken des Dorfes leise durch die Stille klangen.",
      "Jeden Herbst sammeln wir reife Äpfel, backen einen warmen Kuchen und erzählen Geschichten am knisternden Feuer.",
      "Die alte Buchhändlerin ordnete ihre staubigen Bände und summte dabei eine fröhliche Melodie aus ihrer Jugend.",
    ],
    "ru": [
      "Прохладный утренний туман плыл над рекой, пока тихие колокола деревни звенели в прозрачном осеннем воздухе.",
      "Каждую осень мы собираем спелые яблоки, печём тёплый пирог и рассказываем истории у потрескивающего огня.",
      "Старый рыбак чинил свои сети, напевая медленную мелодию, которую выучил ещё в далёком детстве.",
    ],
    "zh": [
      "清晨的薄雾漂浮在河面上，村庄的钟声在安静的空气中缓缓回荡。",
      "每年秋天我们都会采摘成熟的苹果，烤一个温暖的蛋糕，围着炉火讲述往事。",
      "老渔夫一边修补渔网，一边哼着他年轻时学会的那首缓慢的歌谣。",
    ],
    "ja": [
      "朝の冷たい霧が川面を流れ、村の鐘の音が静かな空気の中をゆっくりと響いていた。",
      "毎年秋になると、熟した林檎を集めて温かい菓子を焼き、炉端で昔の話を語り合う。",
      "年老いた漁師は網を繕いながら、若い頃に覚えた穏やかな旋律を静かに口ずさんでいた。",
    ],
    "ko": [
      "차가운 아침 안개가 강 위를 흐르고, 마을의 종소리가 고요한 공기 속으로 천천히 퍼져 나갔다.",
      "가을마다 우리는 잘 익은 사과를 모아 따뜻한 과자를 굽고, 난롯가에서 옛이야기를 나눈다.",
      "나이 든 어부는 그물을 손질하며 젊은 시절에 배운 잔잔한 가락을 조용히 흥얼거렸다.",
    ],
  ]

  /// Language codes with curated sentences, sorted for stable error messages.
  static var supportedLanguages: [String] { pools.keys.sorted() }

  /// Full-name, dialect, and `auto` aliases accepted alongside ISO 639-1 codes.
  ///
  /// This must accept **everything** `TTSLanguage(languageCode:)` accepts.
  /// `CastVoiceGenerator` resolves the audition sentence *before* it constructs
  /// the `TTSLanguage`, and does so outside the per-character `do`/`catch` — so
  /// any input this table misses but `TTSLanguage` would have accepted aborts
  /// the entire cast run rather than skipping one character.
  ///
  /// Dialects collapse to the base language they are spoken in, since the
  /// audition only needs a phonetically representative utterance and Qwen3-TTS
  /// conditions the accent from the voice prompt, not the sentence. `auto` means
  /// "let the model infer," which leaves no language to select on; English is the
  /// historical default for that path.
  private static let aliases: [String: String] = [
    "english": "en", "spanish": "es", "french": "fr", "italian": "it",
    "portuguese": "pt", "german": "de", "russian": "ru", "chinese": "zh",
    "japanese": "ja", "korean": "ko",
    "mandarin": "zh",
    "beijing_dialect": "zh", "beijingdialect": "zh", "beijing": "zh",
    "sichuan_dialect": "zh", "sichuandialect": "zh", "sichuan": "zh",
    "auto": "en",
  ]

  /// Reduces a BCP-47 tag or language name to the ISO 639-1 code used as a pool
  /// key: `es-MX` and `es_MX` both become `es`, `English` becomes `en`.
  static func baseCode(_ rawLanguage: String) -> String {
    let lowered = rawLanguage.trimmingCharacters(in: .whitespaces).lowercased()

    // Look up the raw form first. Aliases like `beijing_dialect` carry a literal
    // underscore, so checking before separator normalization is what keeps them
    // reachable — normalizing first turns them into `beijing-dialect`, which
    // matches nothing and then splits to a bare `beijing`.
    if let alias = aliases[lowered] { return alias }

    let normalized = lowered.replacingOccurrences(of: "_", with: "-")
    if let alias = aliases[normalized] { return alias }

    let base = normalized.split(separator: "-").first.map(String.init) ?? normalized
    return aliases[base] ?? base
  }

  /// Returns the canonical audition sentence for `rawLanguage`.
  ///
  /// Deterministic by design: the same language always yields the same sentence,
  /// so a given `voicePrompt` reproduces the same `.vox` embedding.
  ///
  /// - Parameter rawLanguage: A BCP-47 code or language name (`es`, `es-MX`, `English`).
  /// - Throws: ``AuditionSentenceError/unsupportedLanguage(_:supported:)`` when
  ///   no pool covers the language.
  static func auditionSentence(language rawLanguage: String) throws -> String {
    try auditionSentence(language: rawLanguage, variant: 0)
  }

  /// Returns an alternate audition sentence for `rawLanguage`.
  ///
  /// - Parameter variant: Index into the language's pool, wrapped so any value
  ///   is valid. `0` is the canonical sentence.
  static func auditionSentence(language rawLanguage: String, variant: Int) throws -> String {
    let code = baseCode(rawLanguage)
    guard let pool = pools[code], !pool.isEmpty else {
      throw AuditionSentenceError.unsupportedLanguage(
        rawLanguage, supported: supportedLanguages)
    }
    // Wrap rather than trap, and keep negatives well-defined.
    let index = ((variant % pool.count) + pool.count) % pool.count
    return pool[index]
  }

  /// Returns the audition sentence for one character, rotating through the
  /// language's pool so a cast hears a spread of passages.
  ///
  /// The rotation is keyed by a stable hash of the character name, so the same
  /// character always gets the same sentence and its `.vox` stays reproducible.
  /// An explicit `variant` overrides the rotation for every character.
  static func auditionSentence(
    language rawLanguage: String, character: String, variant: Int? = nil
  ) throws -> String {
    try auditionSentence(language: rawLanguage, variant: variant ?? rotationIndex(for: character))
  }

  /// FNV-1a over the uppercased, trimmed name. `Hasher` is seeded per process,
  /// so it can't be used here — the index must match across runs and machines.
  static func rotationIndex(for character: String) -> Int {
    let key = character.trimmingCharacters(in: .whitespaces).uppercased()
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in key.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x0000_0100_0000_01b3
    }
    return Int(hash % 1_000_003)
  }
}
