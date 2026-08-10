import SwiftUI
import WidgetKit

@main
struct AtlasWidgetBundle: WidgetBundle {
    var body: some Widget {
        AtlasStatusWidget()
        AgentLiveActivityWidget()
    }
}
