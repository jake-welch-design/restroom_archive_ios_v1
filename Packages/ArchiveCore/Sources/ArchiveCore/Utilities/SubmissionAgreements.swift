import Foundation

public enum SubmissionAgreements {
    /// Exact agreement list validated server-side by `/api/auth/request-submission-access`.
    /// Preserve the sole, perpetual license wording verbatim.
    public static let all: [String] = [
        "Scans will be shot from every angle and complete, without significant holes, drift, or blobby geometry. Minor artifacts are permissible, particularly around mirrors and other reflective surfaces.",
        "Scans will be cropped and cleaned to remove false spaces caused by reflective surfaces.",
        "Toilets must be flushed before scanning.",
        "I will avoid scanning restrooms that aren't private or a single room. I will never scan if there are other people present.",
        "I will only scan publicly accessible restrooms, I will never trespass or scan residential spaces.",
        "I will use my best judgement when submitting. I won't submit anything too traumatizing or gross.",
        "I agree to always be respectful.",
        "The scans I submit are my own work and mine to contribute. I keep ownership and copyright, and I may use my scans anywhere else. I grant The Restroom Archive a sole, perpetual license to hold and display them on the site, meaning I will not license the same scan to anyone else, and I understand the archive will use them on the site and nowhere else: never sold, never transferred, never released as datasets, never used for AI training."
    ]
}

