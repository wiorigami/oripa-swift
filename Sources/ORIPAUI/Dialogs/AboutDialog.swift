// About dialog — port of `AboutDialogFragment` + `dialog_about.xml` + `about_text_*`.
//
// Android shows an AlertDialog with a scrolling view of: headline / "version <VERSION_NAME>" /
// subheading / description / credits (autoLink="web") / disclaimer and a single "Close"
// button. The port additionally shows the ORIPA mark at the top (the task requires it; the
// Android layout has no logo, exactly as noted in the web-port report).
import SwiftUI
import ORIPACore

/// About dialog content + spec builder.
@MainActor
public enum AboutDialog {

    /// `about_text_headline`.
    public static let headline = "ORIPA for Android"
    /// `about_text_version` — "version %s".
    public static let versionFormat = "version %@"
    /// `about_text_subheading`.
    public static let subheading = "Origami Pattern Editor"
    /// `about_text_description`.
    public static let description = "Draw and test origami crease patterns on the go! Based on Jun Mitani's ORIPA desktop application, ORIPA for Android lets users check their crease patterns for local flat foldability and fold them on mobile devices, too."
    /// `about_text_disclaimer`.
    public static let disclaimer = "ORIPA for Android is free software that is provided \"as is\" and comes WITHOUT WARRANTY of any kind, express or implied."
    /// `close`.
    public static let close = "Close"

    /// `about_text_credits` lines: text lines, web links, and 20 dp spacers.
    public enum CreditLine {
        case text(String)
        case link(String)
        case spacer
    }

    public static let credits: [CreditLine] = [
        .text("ORIPA for Android: © 2016-2018 Michelle Fung"),
        .link("http://www.michellefung.net"),
        .spacer,
        .text("ORIPA S: © 2012 Ouchi Koji"),
        .link("https://github.com/Ooouch1"),
        .spacer,
        .text("ORIPA: © 2005-2009 Jun Mitani"),
        .link("http://mitani.cs.tsukuba.ac.jp"),
    ]

    /// Build the About dialog spec (shown through `AppModel.dialogs`).
    public static func makeSpec(app: AppModel) -> OrDialogSpec {
        OrDialogSpec(
            content: AnyView(AboutDialogContent(version: AppInfo.version)),
            buttons: [OrDialogButton(close, primary: true)],
            width: 560
        )
    }

    /// Show the About dialog (`ui.dialogs.about.show()`).
    public static func show(app: AppModel) {
        app.dialogs.show(makeSpec(app: app))
    }
}

/// The scrolling About content (`dialog_about.xml`).
public struct AboutDialogContent: View {
    public var version: String

    public init(version: String = AppInfo.version) {
        self.version = version
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Port addition: the ORIPA mark above the headline.
            OripaLogo(.mark, height: 72)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

            Text(AboutDialog.headline)
                .font(.system(size: 24))
                .foregroundColor(OrTheme.textPrimary)
                // `.projects-about-headline { font-size: 24px; line-height: 32px }`
                .orLineHeight(32, fontSize: 24)
                .fixedSize(horizontal: false, vertical: true)

            Text(AboutDialog.versionFormat.replacingOccurrences(of: "%@", with: version))
                .font(.system(size: 14))
                .foregroundColor(OrTheme.textPrimary)
                .orLineHeight(20, fontSize: 14)

            // `dialog_about.xml`: the subheading follows the version line with no margin.
            Text(AboutDialog.subheading)
                .font(.system(size: 16))
                .foregroundColor(OrTheme.textPrimary)
                .orLineHeight(24, fontSize: 16)

            Text(AboutDialog.description)
                .font(.system(size: 14))
                .foregroundColor(OrTheme.textPrimary)
                .orLineHeight(20, fontSize: 14)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(AboutDialog.credits.enumerated()), id: \.offset) { _, line in
                    creditView(line)
                }
            }
            .padding(.top, 16)

            Text(AboutDialog.disclaimer)
                .font(.system(size: 12))
                .foregroundColor(OrTheme.textPrimary)
                // `.projects-about-disclaimer { font-size: 12px; line-height: 16px }`
                .orLineHeight(16, fontSize: 12)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func creditView(_ line: AboutDialog.CreditLine) -> some View {
        switch line {
        case .text(let text):
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(OrTheme.textPrimary)
                .orLineHeight(20, fontSize: 14)
                .fixedSize(horizontal: false, vertical: true)
        case .link(let urlString):
            if let url = URL(string: urlString) {
                // Android autoLink="web" + textColorLink = accent.
                Link(destination: url) {
                    Text(urlString)
                        .font(.system(size: 14))
                        .foregroundColor(OrTheme.accent)
                        .orLineHeight(20, fontSize: 14)
                        .underline(false)
                }
                .buttonStyle(.plain)
            } else {
                Text(urlString)
                    .font(.system(size: 14))
                    .foregroundColor(OrTheme.accent)
                    .orLineHeight(20, fontSize: 14)
            }
        case .spacer:
            Color.clear.frame(height: 20)
        }
    }
}
