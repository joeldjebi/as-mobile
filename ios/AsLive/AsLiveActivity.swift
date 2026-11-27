import ActivityKit
import SwiftUI
import WidgetKit

// Données envoyées par l'app Flutter (plugin live_activities) — le nom doit rester EXACTEMENT celui-ci
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  public struct ContentState: Codable, Hashable {}
  var id = UUID()
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String { "\(id)_\(key)" }
}

/// Même groupe que l'app (Signing & Capabilities › App Groups)
let asDefaults = UserDefaults(suiteName: "group.ci.adjamesmart.adjameSmart")!
/// Safran de la charte Adjamé-Smart (#E8962A), lisible sur fond sombre
let asSaffron = Color(red: 0.910, green: 0.588, blue: 0.165)

/// Valeurs lues pour la Live Activity d'une commande
struct AsLiveValues {
  let title: String
  let subtitle: String
  let step: Int // 1 : livreur vers la boutique · 2 : colis en route
  let eta: Date?

  init(_ a: LiveActivitiesAppAttributes) {
    title = asDefaults.string(forKey: a.prefixedKey("title")) ?? "Votre commande"
    subtitle = asDefaults.string(forKey: a.prefixedKey("subtitle")) ?? ""
    step = asDefaults.integer(forKey: a.prefixedKey("step"))
    let epoch = asDefaults.double(forKey: a.prefixedKey("etaEpoch"))
    eta = epoch > Date().timeIntervalSince1970 ? Date(timeIntervalSince1970: epoch) : nil
  }
}

/// Temps restant avant l'arrivée : le compte à rebours tourne seul, même sans mise à jour de l'app
struct AsEta: View {
  let eta: Date?
  var body: some View {
    if let eta {
      Text(timerInterval: Date()...eta, countsDown: true)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    } else {
      Image(systemName: "scooter")
    }
  }
}

/// Avancement : commandée → livreur à la boutique → en route → livrée
struct AsProgress: View {
  let v: AsLiveValues
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ProgressView(value: Double(max(v.step, 1)), total: 3).tint(asSaffron)
      Text(v.step >= 2 ? "Colis récupéré · en route" : "Le livreur va chercher votre colis")
        .font(.caption2).foregroundStyle(.white.opacity(0.6))
    }
  }
}

struct AsLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      // Écran verrouillé : titre en couleur, livreur, temps restant en grand, avancement
      let v = AsLiveValues(context.attributes)
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Text(v.title).font(.headline).foregroundStyle(asSaffron).lineLimit(1)
            if !v.subtitle.isEmpty {
              Text(v.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
            }
          }
          Spacer()
          AsEta(eta: v.eta)
            .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white)
        }
        AsProgress(v: v)
      }
      .padding(16)
      .activityBackgroundTint(Color.black.opacity(0.75))
      .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let v = AsLiveValues(context.attributes)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("Livraison", systemImage: "scooter")
            .font(.caption.weight(.semibold))
            .foregroundStyle(asSaffron)
        }
        DynamicIslandExpandedRegion(.trailing) {
          AsEta(eta: v.eta).font(.title3.monospacedDigit().weight(.semibold))
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            Text(v.title).font(.subheadline.weight(.semibold)).lineLimit(1)
            if !v.subtitle.isEmpty {
              Text(v.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            AsProgress(v: v)
          }
        }
      } compactLeading: {
        Image(systemName: "scooter").foregroundStyle(asSaffron)
      } compactTrailing: {
        AsEta(eta: v.eta).frame(maxWidth: 64)
      } minimal: {
        Image(systemName: "scooter").foregroundStyle(asSaffron)
      }
    }
  }
}

@main
struct AsLiveBundle: WidgetBundle {
  var body: some Widget { AsLiveActivity() }
}
