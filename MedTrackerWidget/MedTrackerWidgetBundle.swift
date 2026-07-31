import WidgetKit
import SwiftUI

@main
struct MedTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        MedTrackerWidget()
        MedTrackerMediumWidget()
        MedTrackerInteractiveWidget()
    }
}