using System;

namespace Envoice.MongoIdentity.Models
{
    /// <summary>
    /// An occurance of a user account confirmation
    /// </summary>
    public class ConfirmationOccurrence : Occurrence
    {
        public ConfirmationOccurrence()
        {
        }

        public ConfirmationOccurrence(DateTime confirmedOn) : base(confirmedOn)
        {
        }
    }
}
