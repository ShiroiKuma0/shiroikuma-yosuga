import QtQuick
import Ripose.Memento

MetaLabel {
    id: root

    required property Tag tag

    text: root.tag?.name ?? ""
    tip: root.tag?.notes ?? ""
    color: {
        if (root.tag.category === "name")
        {
            return MementoSettings.interfaceSearchTagNameColor;
        }
        else if (root.tag.category === "expression")
        {
            return MementoSettings.interfaceSearchTagExpressionColor;
        }
        else if (root.tag.category === "popular")
        {
            return MementoSettings.interfaceSearchTagPopularColor;
        }
        else if (root.tag.category === "frequent")
        {
            return MementoSettings.interfaceSearchTagFrequentColor;
        }
        else if (root.tag.category === "archaism")
        {
            return MementoSettings.interfaceSearchTagArchaismColor;
        }
        else if (root.tag.category === "dictionary")
        {
            return MementoSettings.interfaceSearchTagDictionaryColor;
        }
        else if (root.tag.category === "frequency")
        {
            return MementoSettings.interfaceSearchTagFrequencyColor;
        }
        else if (root.tag.category === "partOfSpeech")
        {
            return MementoSettings.interfaceSearchTagPosColor;
        }
        else if (root.tag.category === "search")
        {
            return MementoSettings.interfaceSearchTagSearchColor;
        }
        else if (root.tag.category === "pitch-accent-dictionary")
        {
            return MementoSettings.interfaceSearchTagPitchAccentColor;
        }
        else
        {
            return MementoSettings.interfaceSearchTagDefaultColor;
        }
    }
}
