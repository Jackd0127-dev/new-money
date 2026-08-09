import SwiftUI

struct CreditMetricGrid: View {
    struct Item: Identifiable {
        var id: String
        var label: String
        var detail: String?
        var value: String
        var valueDetail: String?
        var labelColor: Color
        var valueColor: Color
        var detailColor: Color
        var valueDetailColor: Color

        init(
            id: String? = nil,
            label: String,
            detail: String? = nil,
            value: String,
            valueDetail: String? = nil,
            labelColor: Color = AppTheme.Colors.secondaryText,
            valueColor: Color = AppTheme.Colors.primaryText,
            detailColor: Color = AppTheme.Colors.secondaryText,
            valueDetailColor: Color = AppTheme.Colors.secondaryText
        ) {
            self.id = id ?? label
            self.label = label
            self.detail = detail
            self.value = value
            self.valueDetail = valueDetail
            self.labelColor = labelColor
            self.valueColor = valueColor
            self.detailColor = detailColor
            self.valueDetailColor = valueDetailColor
        }
    }

    static let regularPresentation = "twoColumnGrid"
    static let accessibilityPresentation = "stackedRows"

    var items: [Item]
    var spacing: CGFloat = AppTheme.Spacing.sm

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedRows
            } else {
                alignedGrid
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var alignedGrid: some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: AppTheme.Spacing.lg,
            verticalSpacing: spacing
        ) {
            ForEach(items) { item in
                GridRow(alignment: .firstTextBaseline) {
                    label(item)

                    value(item)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stackedRows: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    label(item)
                    value(item)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func label(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.label)
                .font(.subheadline)
                .foregroundStyle(item.labelColor)

            if let detail = item.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(item.detailColor)
            }
        }
    }

    private func value(_ item: Item) -> some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
            Text(item.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.valueColor)

            if let valueDetail = item.valueDetail {
                Text(valueDetail)
                    .font(.caption)
                    .foregroundStyle(item.valueDetailColor)
            }
        }
    }
}
