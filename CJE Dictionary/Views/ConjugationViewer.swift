//
//  ConjugationViewer.swift
//  CJE Dictionary
//
//  Created by Hunter Han on 1/7/24.
//

import SwiftUI

struct ConjugationSheet: View {
    let positive: [ConjugatedVerb]
    let negative: [ConjugatedVerb]
    let formalPositive: [ConjugatedVerb]
    let formalNegative: [ConjugatedVerb]
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
#else
    private let isCompact = false
#endif
    
    init(conjugatedVerbs: [ConjugatedVerb]) {
        self.positive = conjugatedVerbs.filter({ !$0.isFormal && !$0.isNegative })
        self.negative = conjugatedVerbs.filter({ !$0.isFormal && $0.isNegative })
        self.formalPositive = conjugatedVerbs.filter({ $0.isFormal && !$0.isNegative })
        self.formalNegative = conjugatedVerbs.filter({ $0.isFormal && $0.isNegative })
    }
    
    var body: some View {
        ScrollView {
            Text("Conjugations")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            Text("Positive")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.trailing, .leading], 20)
            ConjugationGrid(conjugations: positive)
            Text("Negative")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.trailing, .leading, .top], 20)
            ConjugationGrid(conjugations: negative)
            Text("Formal Positive")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.trailing, .leading, .top], 20)
            ConjugationGrid(conjugations: formalPositive)
            Text("Formal Negative")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.trailing, .leading, .top], 20)
            ConjugationGrid(conjugations: formalNegative)
        }
    }
}

struct ConjugationViewer: View {
    @State var isPresented: Bool = false
    @Environment(\.colorScheme) var colorScheme
    let conjugatedVerbs: [ConjugatedVerb]
    let topBottomPadding: CGFloat = 6
    
    var body: some View {
        var displayedVerbs: [ConjugatedVerb] = []
        for conjugatedVerb in conjugatedVerbs {
            if displayedVerbs.last?.form != conjugatedVerb.form {
                displayedVerbs.append(conjugatedVerb)
            }
        }
        return GeometryReader { geometry in
            HStack {
                ForEach(displayedVerbs, id: \.self) { verb in
                    HStack{
                        VStack {
                            Text(LocalizedStringKey(verb.form)).font(.subheadline)
                                .fixedSize()
                                .lineLimit(1)
                            Text(verb.verb)
                                .font(.caption)
                                .fixedSize()
                                .lineLimit(1)
                        }
                        Divider()
                    }.overlay(alignment: .center) {
                        GeometryReader { overlayGeo in
                            Color(colorScheme == .dark ? .black : .white)
                                .opacity(
                                    overlayGeo.frame(in: .global).maxX < geometry.frame(in: .global).maxX - 10 ? 0.0 : 1.0
                                )
                            // Adjust by 6 since divider width is factored in, however it doesn't look good, so we adjust
                            let imageWidth = geometry.frame(in: .global).maxX - overlayGeo.frame(in: .global).minX - 6
                            let imageHeight = geometry.frame(in: .global).maxY - geometry.frame(in: .global).minY
                            if imageWidth > 0, imageHeight > 0 {
                                Image(systemName: "arrow.forward")
                                    .fontWeight(.medium)
                                    .foregroundStyle(
                                        .gray
                                    )
                                    .font(.caption2)
                                    .opacity(
                                        (overlayGeo.frame(in: .global).maxX < geometry.frame(in: .global).maxX - 10 || geometry.frame(in: .global).maxX - overlayGeo.frame(in: .global).minX < 10) ? 0.0 : 1.0
                                    ).frame(width: imageWidth, height: imageHeight, alignment: .center)
                            }
                        }
                    }
                }
            }.frame(width: geometry.size.width - 15, height: geometry.size.height, alignment: .leading)
                .onTapGesture {
                    isPresented = true
                }.sheet(isPresented: $isPresented) {
                    ConjugationSheet(conjugatedVerbs: conjugatedVerbs)
                }.padding([.trailing], 6)
                .padding([.leading], 10)
                .padding([.top, .bottom], topBottomPadding)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.gray, lineWidth: 2)
                }.fixedSize()
        }
    }
}

#Preview {
    ConjugationViewer(conjugatedVerbs: [CJE_Dictionary.ConjugatedVerb(form: "Non-past", isNegative: false, isFormal: false, verb: "いく"), CJE_Dictionary.ConjugatedVerb(form: "Non-past", isNegative: false, isFormal: true, verb: "いきます"), CJE_Dictionary.ConjugatedVerb(form: "Non-past", isNegative: true, isFormal: false, verb: "いかない"), CJE_Dictionary.ConjugatedVerb(form: "Non-past", isNegative: true, isFormal: true, verb: "いきません"), CJE_Dictionary.ConjugatedVerb(form: "Past (~ta)", isNegative: false, isFormal: false, verb: "いった"), CJE_Dictionary.ConjugatedVerb(form: "Past (~ta)", isNegative: false, isFormal: true, verb: "いきました"), CJE_Dictionary.ConjugatedVerb(form: "Past (~ta)", isNegative: true, isFormal: false, verb: "いかなかった"), CJE_Dictionary.ConjugatedVerb(form: "Past (~ta)", isNegative: true, isFormal: true, verb: "いきませんでした"), CJE_Dictionary.ConjugatedVerb(form: "Conjunctive (~te)", isNegative: false, isFormal: false, verb: "いって"), CJE_Dictionary.ConjugatedVerb(form: "Conjunctive (~te)", isNegative: false, isFormal: true, verb: "いきまして"), CJE_Dictionary.ConjugatedVerb(form: "Conjunctive (~te)", isNegative: true, isFormal: false, verb: "いかなくて"), CJE_Dictionary.ConjugatedVerb(form: "Conjunctive (~te)", isNegative: true, isFormal: false, verb: "いかないで"), CJE_Dictionary.ConjugatedVerb(form: "Conjunctive (~te)", isNegative: true, isFormal: true, verb: "いきませんで"), CJE_Dictionary.ConjugatedVerb(form: "Provisional (~eba)", isNegative: false, isFormal: false, verb: "いけば"), CJE_Dictionary.ConjugatedVerb(form: "Provisional (~eba)", isNegative: false, isFormal: true, verb: "いきますなら"), CJE_Dictionary.ConjugatedVerb(form: "Provisional (~eba)", isNegative: false, isFormal: true, verb: "いきますならば"), CJE_Dictionary.ConjugatedVerb(form: "Provisional (~eba)", isNegative: true, isFormal: false, verb: "いかなければ"), CJE_Dictionary.ConjugatedVerb(form: "Provisional (~eba)", isNegative: true, isFormal: true, verb: "いきませんなら"), CJE_Dictionary.ConjugatedVerb(form: "Provisional (~eba)", isNegative: true, isFormal: true, verb: "いきませんならば"), CJE_Dictionary.ConjugatedVerb(form: "Potential", isNegative: false, isFormal: false, verb: "いける"), CJE_Dictionary.ConjugatedVerb(form: "Potential", isNegative: false, isFormal: true, verb: "いけます"), CJE_Dictionary.ConjugatedVerb(form: "Potential", isNegative: true, isFormal: false, verb: "いけない"), CJE_Dictionary.ConjugatedVerb(form: "Potential", isNegative: true, isFormal: true, verb: "いけません"), CJE_Dictionary.ConjugatedVerb(form: "Passive", isNegative: false, isFormal: false, verb: "いかれる"), CJE_Dictionary.ConjugatedVerb(form: "Passive", isNegative: false, isFormal: true, verb: "いかれます"), CJE_Dictionary.ConjugatedVerb(form: "Passive", isNegative: true, isFormal: false, verb: "いかれない"), CJE_Dictionary.ConjugatedVerb(form: "Passive", isNegative: true, isFormal: true, verb: "いかれません"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: false, isFormal: false, verb: "いかせる"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: false, isFormal: false, verb: "いかす"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: false, isFormal: true, verb: "いかせます"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: false, isFormal: true, verb: "いかします"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: true, isFormal: false, verb: "いかせない"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: true, isFormal: false, verb: "いかさない"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: true, isFormal: true, verb: "いかせません"), CJE_Dictionary.ConjugatedVerb(form: "Causative", isNegative: true, isFormal: true, verb: "いかしません"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: false, isFormal: false, verb: "いかせられる"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: false, isFormal: false, verb: "いかされる"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: false, isFormal: true, verb: "いかせられます"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: false, isFormal: true, verb: "いかされます"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: true, isFormal: false, verb: "いかせられない"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: true, isFormal: false, verb: "いかされない"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: true, isFormal: true, verb: "いかせられません"), CJE_Dictionary.ConjugatedVerb(form: "Causative-Passive", isNegative: true, isFormal: true, verb: "いかされません"), CJE_Dictionary.ConjugatedVerb(form: "Volitional", isNegative: false, isFormal: false, verb: "いこう"), CJE_Dictionary.ConjugatedVerb(form: "Volitional", isNegative: false, isFormal: true, verb: "いきましょう"), CJE_Dictionary.ConjugatedVerb(form: "Volitional", isNegative: true, isFormal: false, verb: "いくまい"), CJE_Dictionary.ConjugatedVerb(form: "Volitional", isNegative: true, isFormal: true, verb: "いきませんまい"), CJE_Dictionary.ConjugatedVerb(form: "Imperative", isNegative: false, isFormal: false, verb: "いけ"), CJE_Dictionary.ConjugatedVerb(form: "Imperative", isNegative: false, isFormal: true, verb: "いきなさい"), CJE_Dictionary.ConjugatedVerb(form: "Imperative", isNegative: true, isFormal: false, verb: "いくな"), CJE_Dictionary.ConjugatedVerb(form: "Imperative", isNegative: true, isFormal: true, verb: "いきなさるな"), CJE_Dictionary.ConjugatedVerb(form: "Conditional (~tara)", isNegative: false, isFormal: false, verb: "いったら"), CJE_Dictionary.ConjugatedVerb(form: "Conditional (~tara)", isNegative: false, isFormal: true, verb: "いきましたら"), CJE_Dictionary.ConjugatedVerb(form: "Conditional (~tara)", isNegative: true, isFormal: false, verb: "いかなかったら"), CJE_Dictionary.ConjugatedVerb(form: "Conditional (~tara)", isNegative: true, isFormal: true, verb: "いきませんでしたらっjっっっづく"), CJE_Dictionary.ConjugatedVerb(form: "Alternative (~tari)", isNegative: false, isFormal: false, verb: "いったり"), CJE_Dictionary.ConjugatedVerb(form: "Alternative (~tari)", isNegative: false, isFormal: true, verb: "いきましたり"), CJE_Dictionary.ConjugatedVerb(form: "Alternative (~tari)", isNegative: true, isFormal: false, verb: "いかなかったり"), CJE_Dictionary.ConjugatedVerb(form: "Alternative (~tari)", isNegative: true, isFormal: true, verb: "いきませんでしたり"), CJE_Dictionary.ConjugatedVerb(form: "Continuative (~i)", isNegative: false, isFormal: false, verb: "いき")]).frame(height: 45).padding(36)
}

struct ConjugationGrid: View {
    let conjugations: [ConjugatedVerb]
    
    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(conjugations) { conj in
                GridRow(alignment: .firstTextBaseline) {
                    Text(LocalizedStringKey(conj.form))
                        .font(.body)
                        .padding([.trailing, .leading], 20)
                    Text(conj.verb)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.padding([.top], 3)
    }
}
