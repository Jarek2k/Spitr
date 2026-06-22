//
//  OnboardingView.swift
//  Spitr
//
//  First-launch flow that explains and requests the three permissions in plain
//  language. Each is justified individually; the user can also continue and
//  grant missing ones later from the menu.
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var controller: RecordingController
    var onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Willkommen bei Spitr")
                    .font(.largeTitle.bold())
                Text("Taste halten, sprechen, loslassen — der Text landet im aktiven Fenster. Alles on-device, ohne Cloud.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                step(number: 1,
                     title: "Mikrofon",
                     detail: "Nimmt nur auf, solange du die Aufnahme-Taste hältst. Kein Dauer-Mithören.",
                     granted: controller.micGranted,
                     action: { controller.requestMicrophone() })

                step(number: 2,
                     title: "Spracherkennung",
                     detail: "Wandelt deine Aufnahme on-device in Text um.",
                     granted: controller.speechGranted,
                     action: { controller.requestSpeech() })

                step(number: 3,
                     title: "Bedienungshilfen",
                     detail: "Damit Spitr die Aufnahme-Taste global erkennt und den Text einfügt. Schalter in den Systemeinstellungen aktivieren.",
                     granted: controller.accessibilityTrusted,
                     action: { controller.openAccessibility() })
            }

            HStack {
                if controller.allPermissionsGranted {
                    Label("Alles bereit", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Fehlende Rechte kannst du später im Menü ergänzen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(controller.allPermissionsGranted ? "Los geht's" : "Später") {
                    onFinish()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 470)
        .onAppear { controller.refreshPermissions() }
        .task {
            // Accessibility is granted in System Settings, outside the app, so
            // poll while onboarding is visible to reflect the change live.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                controller.refreshPermissions()
            }
        }
    }

    private func step(
        number: Int,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(granted ? Color.green : Color.secondary.opacity(0.2))
                    .frame(width: 26, height: 26)
                if granted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text(verbatim: "\(number)").font(.caption.bold())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.top, 2)
            } else {
                Button("Erlauben", action: action)
            }
        }
    }
}
