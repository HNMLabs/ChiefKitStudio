import Foundation

// MARK: - Domain Presets

public enum LocalizationDomainPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case studioCoreUI
    case authenticationAndSecurity
    case fintechAndCommerce
    case onboardingAndSurveys
    case accessibilityAndErrors

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .studioCoreUI: "Studio Core & Workspace Chrome"
        case .authenticationAndSecurity: "Authentication, Passkeys & Biometrics"
        case .fintechAndCommerce: "Fintech Ledger, Checkout & Subscriptions"
        case .onboardingAndSurveys: "NotebookFlow Onboarding & Surveys"
        case .accessibilityAndErrors: "Accessibility Hints & Recovery Alerts"
        }
    }

    public var defaultCatalogName: String {
        switch self {
        case .studioCoreUI: "StudioCore"
        case .authenticationAndSecurity: "AuthSecurity"
        case .fintechAndCommerce: "CommerceLedger"
        case .onboardingAndSurveys: "OnboardingFlows"
        case .accessibilityAndErrors: "AccessibilityErrors"
        }
    }
}

// MARK: - StudioBuiltInTranslations

public enum StudioBuiltInTranslations {
    public static let starterLocales: [LocaleCode] = [.en, .tr, .de, .fr, .es, .ja, .ar]

    public static func catalog(for domain: LocalizationDomainPreset) -> StringCatalogDocument {
        switch domain {
        case .studioCoreUI:
            return buildStudioCoreUICatalog()
        case .authenticationAndSecurity:
            return buildAuthenticationAndSecurityCatalog()
        case .fintechAndCommerce:
            return buildFintechAndCommerceCatalog()
        case .onboardingAndSurveys:
            return buildOnboardingAndSurveysCatalog()
        case .accessibilityAndErrors:
            return buildAccessibilityAndErrorsCatalog()
        }
    }

    public static func unifiedMasterCatalog() -> StringCatalogDocument {
        var master = StringCatalogDocument(
            catalogName: "ChiefKitMaster",
            sourceLanguage: .en,
            targetLocales: starterLocales
        )
        for preset in LocalizationDomainPreset.allCases {
            master = master.merging(catalog(for: preset))
        }
        return master
    }

    // MARK: - 1) Studio Core UI

    private static func buildStudioCoreUICatalog() -> StringCatalogDocument {
        var doc = StringCatalogDocument(
            catalogName: LocalizationDomainPreset.studioCoreUI.defaultCatalogName,
            sourceLanguage: .en,
            targetLocales: starterLocales
        )

        addSimple(&doc, key: "studio.action.save", comment: "Primary save button", budget: 24, values: [
            .en: "Save Changes",
            .tr: "Değişiklikleri Kaydet",
            .de: "Änderungen speichern",
            .fr: "Enregistrer",
            .es: "Guardar cambios",
            .ja: "変更を保存",
            .ar: "حفظ التغييرات"
        ])

        addSimple(&doc, key: "studio.action.cancel", comment: "Dismiss modal without saving", budget: 18, values: [
            .en: "Cancel",
            .tr: "Vazgeç",
            .de: "Abbrechen",
            .fr: "Annuler",
            .es: "Cancelar",
            .ja: "キャンセル",
            .ar: "إلغاء"
        ])

        addSimple(&doc, key: "studio.action.export_xcode", comment: "Export starter Xcode project", budget: 32, values: [
            .en: "Export Xcode Project",
            .tr: "Xcode Projesini Dışa Aktar",
            .de: "Xcode-Projekt exportieren",
            .fr: "Exporter le projet Xcode",
            .es: "Exportar proyecto de Xcode",
            .ja: "Xcodeプロジェクトを書き出す",
            .ar: "تصدير مشروع Xcode"
        ])

        addSimple(&doc, key: "studio.canvas.empty_prompt", comment: "Empty state placeholder on visual canvas", values: [
            .en: "Drag components onto the canvas to synthesize SwiftUI.",
            .tr: "SwiftUI kodu üretmek için bileşenleri tuvale sürükleyin.",
            .de: "Ziehe Komponenten auf die Arbeitsfläche, um SwiftUI zu erzeugen.",
            .fr: "Faites glisser des composants sur le canevas pour générer SwiftUI.",
            .es: "Arrastra componentes al lienzo para generar código SwiftUI.",
            .ja: "キャンバスにコンポーネントをドラッグしてSwiftUIを生成します。",
            .ar: "اسحب المكوّنات إلى مساحة العمل لتوليد كود SwiftUI."
        ])

        addSimple(&doc, key: "studio.status.synced_user", comment: "Workspace sync banner with username", values: [
            .en: "Synced workspace for %@",
            .tr: "%@ için çalışma alanı eşitlendi",
            .de: "Arbeitsbereich für %@ synchronisiert",
            .fr: "Espace synchronisé pour %@",
            .es: "Espacio sincronizado para %@",
            .ja: "%@ のワークスペースを同期しました",
            .ar: "تمت مزامنة مساحة العمل للمستخدم %@"
        ])

        addPlural(&doc, key: "studio.canvas.selected_blocks", comment: "Count of selected UI blocks on canvas", formsByLocale: [
            .en: [.one: "%lld block selected", .other: "%lld blocks selected"],
            .tr: [.one: "%lld blok seçildi", .other: "%lld blok seçildi"],
            .de: [.one: "%lld Block ausgewählt", .other: "%lld Blöcke ausgewählt"],
            .fr: [.one: "%lld bloc sélectionné", .other: "%lld blocs sélectionnés"],
            .es: [.one: "%lld bloque seleccionado", .other: "%lld bloques seleccionados"],
            .ja: [.other: "%lld 個のブロックを選択中"],
            .ar: [
                .zero: "لم يتم تحديد أي عنصر",
                .one: "تم تحديد عنصر واحد (%lld)",
                .two: "تم تحديد عنصرين (%lld)",
                .few: "تم تحديد %lld عناصر",
                .many: "تم تحديد %lld عنصرًا",
                .other: "تم تحديد %lld عنصر"
            ]
        ])

        // Device variation for inspector shortcut prompt
        doc.upsertDeviceVariation(key: "studio.gesture.inspect", comment: "Platform gesture hint", locale: .en, device: .mac, value: "Right-click block to inspect tokens")
        doc.upsertDeviceVariation(key: "studio.gesture.inspect", locale: .en, device: .iphone, value: "Long-press block to inspect")
        doc.upsertDeviceVariation(key: "studio.gesture.inspect", locale: .en, device: .applevision, value: "Pinch and hold block to inspect")
        doc.upsertSimpleTranslation(key: "studio.gesture.inspect", locale: .en, value: "Select block to inspect tokens")
        doc.upsertSimpleTranslation(key: "studio.gesture.inspect", locale: .tr, value: "Belirteçleri incelemek için bloğu seçin")
        doc.upsertSimpleTranslation(key: "studio.gesture.inspect", locale: .de, value: "Block auswählen, um Tokens zu prüfen")
        doc.upsertSimpleTranslation(key: "studio.gesture.inspect", locale: .fr, value: "Sélectionnez un bloc pour inspecter les jetons")
        doc.upsertSimpleTranslation(key: "studio.gesture.inspect", locale: .es, value: "Selecciona un bloque para inspeccionar tokens")
        doc.upsertSimpleTranslation(key: "studio.gesture.inspect", locale: .ja, value: "ブロックを選択してトークンを確認")
        doc.upsertSimpleTranslation(key: "studio.gesture.inspect", locale: .ar, value: "حدّد العنصر لفحص خصائص التصميم")

        return doc
    }

    // MARK: - 2) Authentication & Security

    private static func buildAuthenticationAndSecurityCatalog() -> StringCatalogDocument {
        var doc = StringCatalogDocument(
            catalogName: LocalizationDomainPreset.authenticationAndSecurity.defaultCatalogName,
            sourceLanguage: .en,
            targetLocales: starterLocales
        )

        addSimple(&doc, key: "auth.signin.title", comment: "Sign-in screen header", budget: 36, values: [
            .en: "Welcome Back",
            .tr: "Tekrar Hoş Geldiniz",
            .de: "Willkommen zurück",
            .fr: "Bon retour",
            .es: "Te damos la bienvenida",
            .ja: "おかえりなさい",
            .ar: "مرحبًا بعودتك"
        ])

        addSimple(&doc, key: "auth.passkey.cta", comment: "Passkey biometric sign-in CTA", budget: 28, values: [
            .en: "Continue with Passkey",
            .tr: "Geçiş Anahtarıyla Devam Et",
            .de: "Mit Passkey fortfahren",
            .fr: "Continuer avec une clé d’accès",
            .es: "Continuar con llave de acceso",
            .ja: "パスキーで続ける",
            .ar: "المتابعة باستخدام مفتاح المرور"
        ])

        addSimple(&doc, key: "auth.biometric.prompt", comment: "Touch ID / Face ID unlock explanation", values: [
            .en: "Authenticate to unlock encrypted vault keys.",
            .tr: "Şifreli kasa anahtarlarının kilidini açmak için kimliğinizi doğrulayın.",
            .de: "Authentifiziere dich, um verschlüsselte Tresorschlüssel zu entsperren.",
            .fr: "Authentifiez-vous pour déverrouiller les clés chiffrées du coffre.",
            .es: "Autentícate para desbloquear las claves cifradas de la bóveda.",
            .ja: "暗号化されたボールトキーのロックを解除するには認証してください。",
            .ar: "يرجى المصادقة لفتح مفاتيح الخزنة المشفّرة."
        ])

        addSimple(&doc, key: "auth.mfa.code_sent", comment: "Verification code sent to masked destination", values: [
            .en: "Enter the 6-digit verification code sent to %@.",
            .tr: "%@ adresine gönderilen 6 haneli doğrulama kodunu girin.",
            .de: "Gib den 6-stelligen Bestätigungscode ein, der an %@ gesendet wurde.",
            .fr: "Saisissez le code à 6 chiffres envoyé à %@.",
            .es: "Introduce el código de 6 dígitos enviado a %@.",
            .ja: "%@ に送信された6桁の確認コードを入力してください。",
            .ar: "أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى %@."
        ])

        addPlural(&doc, key: "auth.lockout.remaining_attempts", comment: "Remaining password tries before temporary lockout", formsByLocale: [
            .en: [.one: "%lld attempt remaining before lockout", .other: "%lld attempts remaining before lockout"],
            .tr: [.one: "Kilitlenmeden önce %lld deneme hakkı kaldı", .other: "Kilitlenmeden önce %lld deneme hakkı kaldı"],
            .de: [.one: "Noch %lld Versuch vor der Sperrung", .other: "Noch %lld Versuche vor der Sperrung"],
            .fr: [.one: "%lld tentative restante avant verrouillage", .other: "%lld tentatives restantes avant verrouillage"],
            .es: [.one: "Queda %lld intento antes del bloqueo", .other: "Quedan %lld intentos antes del bloqueo"],
            .ja: [.other: "ロックされるまで残り %lld 回の試行が可能です"],
            .ar: [
                .zero: "لم تتبقَّ أي محاولة قبل القفل المؤقت",
                .one: "متبقية محاولة واحدة (%lld) قبل القفل",
                .two: "متبقيتان محاولتان (%lld) قبل القفل",
                .few: "متبقية %lld محاولات قبل القفل",
                .many: "متبقية %lld محاولة قبل القفل",
                .other: "متبقية %lld محاولة قبل القفل"
            ]
        ])

        return doc
    }

    // MARK: - 3) Fintech & Commerce

    private static func buildFintechAndCommerceCatalog() -> StringCatalogDocument {
        var doc = StringCatalogDocument(
            catalogName: LocalizationDomainPreset.fintechAndCommerce.defaultCatalogName,
            sourceLanguage: .en,
            targetLocales: starterLocales
        )

        addSimple(&doc, key: "commerce.checkout.pay_now", comment: "Primary checkout payment button", budget: 24, values: [
            .en: "Pay %.2f",
            .tr: "%.2f Öde",
            .de: "%.2f bezahlen",
            .fr: "Payer %.2f",
            .es: "Pagar %.2f",
            .ja: "%.2f を支払う",
            .ar: "ادفع %.2f"
        ])

        addSimple(&doc, key: "commerce.ledger.posted_badge", comment: "Settled double-entry journal status", budget: 22, values: [
            .en: "Settled",
            .tr: "Mutabakat Tamam",
            .de: "Gebucht",
            .fr: "Comptabilisé",
            .es: "Contabilizado",
            .ja: "決済済み",
            .ar: "تمت التسوية"
        ])

        addSimple(&doc, key: "commerce.receipt.summary", comment: "Order receipt confirmation with reference ID", values: [
            .en: "Receipt %@ has been archived to your ledger.",
            .tr: "%@ numaralı makbuz hesap defterinize arşivlendi.",
            .de: "Beleg %@ wurde in deinem Hauptbuch archiviert.",
            .fr: "Le reçu %@ a été archivé dans votre grand livre.",
            .es: "El recibo %@ se archivó en tu libro mayor.",
            .ja: "領収書 %@ を元帳にアーカイブしました。",
            .ar: "تمت أرشفة الإيصال رقم %@ في دفتر الأستاذ."
        ])

        addPlural(&doc, key: "commerce.cart.item_count", comment: "Shopping bag line item count", formsByLocale: [
            .en: [.one: "%lld item in cart", .other: "%lld items in cart"],
            .tr: [.one: "Sepette %lld ürün", .other: "Sepette %lld ürün"],
            .de: [.one: "%lld Artikel im Warenkorb", .other: "%lld Artikel im Warenkorb"],
            .fr: [.one: "%lld article dans le panier", .other: "%lld articles dans le panier"],
            .es: [.one: "%lld artículo en el carrito", .other: "%lld artículos en el carrito"],
            .ja: [.other: "カート内に %lld 点の商品"],
            .ar: [
                .zero: "السلة فارغة",
                .one: "منتج واحد (%lld) في السلة",
                .two: "منتجان (%lld) في السلة",
                .few: "%lld منتجات في السلة",
                .many: "%lld منتجًا في السلة",
                .other: "%lld منتج في السلة"
            ]
        ])

        return doc
    }

    // MARK: - 4) Onboarding & Surveys

    private static func buildOnboardingAndSurveysCatalog() -> StringCatalogDocument {
        var doc = StringCatalogDocument(
            catalogName: LocalizationDomainPreset.onboardingAndSurveys.defaultCatalogName,
            sourceLanguage: .en,
            targetLocales: starterLocales
        )

        addSimple(&doc, key: "flow.nav.continue", comment: "Advance to next onboarding step", budget: 20, values: [
            .en: "Continue",
            .tr: "Devam Et",
            .de: "Weiter",
            .fr: "Continuer",
            .es: "Continuar",
            .ja: "次へ",
            .ar: "متابعة"
        ])

        addSimple(&doc, key: "flow.nav.back", comment: "Return to previous step", budget: 18, values: [
            .en: "Back",
            .tr: "Geri",
            .de: "Zurück",
            .fr: "Retour",
            .es: "Atrás",
            .ja: "戻る",
            .ar: "رجوع"
        ])

        addSimple(&doc, key: "flow.progress.step_of_total", comment: "Step indicator e.g. Step 2 of 5", values: [
            .en: "Step %1$lld of %2$lld",
            .tr: "Adım %1$lld / %2$lld",
            .de: "Schritt %1$lld von %2$lld",
            .fr: "Étape %1$lld sur %2$lld",
            .es: "Paso %1$lld de %2$lld",
            .ja: "ステップ %1$lld / %2$lld",
            .ar: "الخطوة %1$lld من %2$lld"
        ])

        addSimple(&doc, key: "flow.complete.headline", comment: "Final completion screen title", values: [
            .en: "Your workspace is ready to launch.",
            .tr: "Çalışma alanınız kullanıma hazır.",
            .de: "Dein Arbeitsbereich ist startklar.",
            .fr: "Votre espace de travail est prêt.",
            .es: "Tu espacio de trabajo está listo.",
            .ja: "ワークスペースの準備が完了しました。",
            .ar: "مساحة العمل جاهزة للانطلاق."
        ])

        addPlural(&doc, key: "flow.survey.questions_remaining", comment: "Remaining required questions in survey", formsByLocale: [
            .en: [.one: "%lld required question left", .other: "%lld required questions left"],
            .tr: [.one: "%lld zorunlu soru kaldı", .other: "%lld zorunlu soru kaldı"],
            .de: [.one: "Noch %lld Pflichtfrage offen", .other: "Noch %lld Pflichtfragen offen"],
            .fr: [.one: "%lld question obligatoire restante", .other: "%lld questions obligatoires restantes"],
            .es: [.one: "Falta %lld pregunta obligatoria", .other: "Faltan %lld preguntas obligatorias"],
            .ja: [.other: "必須の質問が残り %lld 問あります"],
            .ar: [
                .zero: "لا توجد أسئلة مطلوبة متبقية",
                .one: "سؤال مطلوب واحد (%lld) متبقٍ",
                .two: "سؤالان مطلوبان (%lld) متبقيان",
                .few: "%lld أسئلة مطلوبة متبقية",
                .many: "%lld سؤالًا مطلوبًا متبقيًا",
                .other: "%lld سؤال مطلوب متبقٍ"
            ]
        ])

        return doc
    }

    // MARK: - 5) Accessibility & Recovery Errors

    private static func buildAccessibilityAndErrorsCatalog() -> StringCatalogDocument {
        var doc = StringCatalogDocument(
            catalogName: LocalizationDomainPreset.accessibilityAndErrors.defaultCatalogName,
            sourceLanguage: .en,
            targetLocales: starterLocales
        )

        addSimple(&doc, key: "a11y.contrast.verified_badge", comment: "VoiceOver announcement for WCAG contrast check", values: [
            .en: "Contrast ratio verified for Dynamic Type legibility.",
            .tr: "Dinamik Punto okunabilirliği için kontrast oranı doğrulandı.",
            .de: "Kontrastverhältnis für Dynamische Schriftgröße geprüft.",
            .fr: "Rapport de contraste vérifié pour la lisibilité Dynamic Type.",
            .es: "Relación de contraste verificada para texto dinámico.",
            .ja: "ダイナミックタイプの視認性コントラスト比を確認済みです。",
            .ar: "تم التحقق من نسبة التباين لضمان وضوح القراءة."
        ])

        addSimple(&doc, key: "error.network.offline_title", comment: "Offline connectivity alert headline", budget: 34, values: [
            .en: "No Internet Connection",
            .tr: "İnternet Bağlantısı Yok",
            .de: "Keine Internetverbindung",
            .fr: "Aucune connexion Internet",
            .es: "Sin conexión a Internet",
            .ja: "インターネット接続がありません",
            .ar: "لا يوجد اتصال بالإنترنت"
        ])

        addSimple(&doc, key: "error.network.retry_cta", comment: "Retry failed request button", budget: 22, values: [
            .en: "Try Again",
            .tr: "Tekrar Dene",
            .de: "Erneut versuchen",
            .fr: "Réessayer",
            .es: "Reintentar",
            .ja: "再試行",
            .ar: "إعادة المحاولة"
        ])

        addSimple(&doc, key: "error.validation.invalid_field", comment: "Inline form field validation message", values: [
            .en: "Please enter a valid value for %@.",
            .tr: "Lütfen %@ alanı için geçerli bir değer girin.",
            .de: "Bitte gib einen gültigen Wert für %@ ein.",
            .fr: "Veuillez saisir une valeur valide pour %@.",
            .es: "Introduce un valor válido para %@.",
            .ja: "%@ に有効な値を入力してください。",
            .ar: "يرجى إدخال قيمة صحيحة في حقل %@."
        ])

        addPlural(&doc, key: "a11y.audit.issues_detected", comment: "Accessibility inspector issue summary", formsByLocale: [
            .en: [.one: "%lld accessibility issue detected", .other: "%lld accessibility issues detected"],
            .tr: [.one: "%lld erişilebilirlik sorunu algılandı", .other: "%lld erişilebilirlik sorunu algılandı"],
            .de: [.one: "%lld Problem mit der Barrierefreiheit erkannt", .other: "%lld Probleme mit der Barrierefreiheit erkannt"],
            .fr: [.one: "%lld problème d’accessibilité détecté", .other: "%lld problèmes d’accessibilité détectés"],
            .es: [.one: "Se detectó %lld problema de accesibilidad", .other: "Se detectaron %lld problemas de accesibilidad"],
            .ja: [.other: "アクセシビリティの問題が %lld 件検出されました"],
            .ar: [
                .zero: "لم يتم رصد أي مشكلة في إمكانية الوصول",
                .one: "تم رصد مشكلة واحدة (%lld) في إمكانية الوصول",
                .two: "تم رصد مشكلتين (%lld) في إمكانية الوصول",
                .few: "تم رصد %lld مشكلات في إمكانية الوصول",
                .many: "تم رصد %lld مشكلة في إمكانية الوصول",
                .other: "تم رصد %lld مشكلة في إمكانية الوصول"
            ]
        ])

        return doc
    }

    // MARK: - Helpers

    private static func addSimple(
        _ doc: inout StringCatalogDocument,
        key: String,
        comment: String,
        budget: Int? = nil,
        values: [LocaleCode: String]
    ) {
        var entry = StringCatalogEntry(
            key: key,
            comment: comment,
            extractionState: .manual,
            shouldTranslate: true,
            maxCharacterBudget: budget
        )
        for (locale, text) in values {
            entry.localizations[locale] = .simple(text, state: .translated)
        }
        doc.entries[key] = entry
    }

    private static func addPlural(
        _ doc: inout StringCatalogDocument,
        key: String,
        comment: String,
        formsByLocale: [LocaleCode: [CLDRPluralCategory: String]]
    ) {
        var entry = StringCatalogEntry(
            key: key,
            comment: comment,
            extractionState: .manual,
            shouldTranslate: true
        )
        for (locale, forms) in formsByLocale {
            entry.localizations[locale] = .plural(forms, state: .translated)
        }
        doc.entries[key] = entry
    }
}
