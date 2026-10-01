import AppKit
import SwiftUI

struct ListControls: NSViewRepresentable {
    let addLabel: String
    let removeLabel: String
    let add: () -> Void
    let remove: (() -> Void)?

    func makeNSView(context: Context) -> NSSegmentedControl {
        let images = [("plus", addLabel), ("minus", removeLabel)].compactMap { NSImage(systemSymbolName: $0, accessibilityDescription: $1) }
        let control = NSSegmentedControl(images: images, trackingMode: .momentary, target: context.coordinator, action: #selector(Coordinator.perform(_:)))
        control.segmentStyle = .smallSquare
        for (segment, label) in [addLabel, removeLabel].enumerated() {
            control.setWidth(24, forSegment: segment)
            control.setToolTip(label, forSegment: segment)
        }
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.controls = self
        control.setEnabled(remove != nil, forSegment: 1)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView control: NSSegmentedControl, context: Context) -> CGSize? {
        control.intrinsicContentSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controls: self)
    }

    final class Coordinator: NSObject {
        var controls: ListControls

        init(controls: ListControls) {
            self.controls = controls
        }

        @objc func perform(_ sender: NSSegmentedControl) {
            if sender.selectedSegment == 0 {
                controls.add()
                return
            }
            controls.remove?()
        }
    }
}
