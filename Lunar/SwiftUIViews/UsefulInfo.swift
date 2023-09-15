import Defaults
import SwiftUI

struct UsefulInfo: View {
    @Default(.infoMenuShown) var infoMenuShown
    @Default(.adaptiveBrightnessMode) var adaptiveBrightnessMode
    @ObservedObject var ami = AMI

    var usefulInfoText: (String, String)? {
        guard infoMenuShown else { return nil }

        switch adaptiveBrightnessMode {
        case .sync:
            #if arch(arm64)
                guard SyncMode.syncNits, let nits = ami.nits else {
                    return nil
                }
                return (nits.intround.s, "nits")
            #else
                return nil
            #endif
        case .sensor:
            guard let lux = ami.lux else {
                return nil
            }
            return (lux > 10 ? lux.intround.s : lux.str(decimals: 1), "lux")
        case .location:
            guard let elevation = ami.sunElevation else {
                return nil
            }
            return ("\((elevation >= 10 || elevation <= -10) ? elevation.intround.s : elevation.str(decimals: 1))°", "sun")
        default:
            return nil
        }
    }

    var body: some View {
        if let (t1, t2) = usefulInfoText {
            VStack(alignment: .leading, spacing: -2) {
                Text(t1)
                    .font(.system(size: 10, weight: .bold, design: .monospaced).leading(.tight))
                Text(t2)
                    .font(.system(size: 9, weight: .semibold, design: .rounded).leading(.tight))
            }
            .foregroundColor(.secondary)
        }
    }
}
