//
//  TenantCard.swift
//  GOPeat
//
//  Created by jonathan calvin sutrisna on 07/04/25.
//

import SwiftUI

struct TenantCard: View {
    let tenant: Tenant
    @State var showTenantDetail = false
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
            Spacer()
            Text(value)
        }
        .font(.caption)
        .foregroundColor(.primary)
    }

    var body: some View {
        Button(action: {
            showTenantDetail = true
            
            // Create user activity for this tenant when opened
            let activity = NSUserActivity(activityType: "com.gopeat.viewTenant")
            activity.title = "Viewing \(tenant.name)"
            activity.userInfo = ["tenantID": tenant.id.uuidString]
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.becomeCurrent()
        }) {
            HStack {
                Image(tenant.image)
                    .resizable()
                    .frame(maxWidth: 80, maxHeight: 80)
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading) {
                    Text(tenant.name)
                        .font(.subheadline)
                        .bold()
                        .padding(.bottom, 5)
                    infoRow(label: "Operational Hours", value: tenant.operationalHours)
                    infoRow(label: "Contact Person", value: tenant.contactPerson)
                    infoRow(
                        label: "Pre-order Information",
                        value:
                            "\((tenant.preorderInformation ?? false) ? "Available" : "Not available")"
                    )
                }

                Spacer()
            }
            .padding(10)
            .background(Color(.systemGray5).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showTenantDetail) {
            showTenantDetail = false
        } content: {
            TenantView(tenant: tenant, foods: tenant.foods, selectedCategories: .constant([]))
        }
    }
}
