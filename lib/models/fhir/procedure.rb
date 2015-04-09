# Copyright (c) 2011-2014, HL7, Inc & The MITRE Corporation
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, 
# are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice, this 
#       list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice, 
#       this list of conditions and the following disclaimer in the documentation 
#       and/or other materials provided with the distribution.
#     * Neither the name of HL7 nor the names of its contributors may be used to 
#       endorse or promote products derived from this software without specific 
#       prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.

module FHIR
    class Procedure 
        
        include Mongoid::Document
        include Mongoid::History::Trackable
        include FHIR::Element
        include FHIR::Resource
        include FHIR::Formats::Utilities
        include FHIR::Serializer::Utilities
        extend FHIR::Deserializer::Procedure
        
        SEARCH_PARAMS = [
            'date',
            'performer',
            'patient',
            'location',
            'encounter',
            'type'
            ]
        
        VALID_CODES = {
            status: [ "in-progress", "aborted", "completed", "entered-in-error" ]
        }
        
        # This is an ugly hack to deal with embedded structures in the spec bodySite
        class ProcedureBodySiteComponent
        include Mongoid::Document
        include FHIR::Element
        include FHIR::Formats::Utilities
            embeds_one :siteCodeableConcept, class_name:'FHIR::CodeableConcept'
            validates_presence_of :siteCodeableConcept
            embeds_one :siteReference, class_name:'FHIR::Reference'
            validates_presence_of :siteReference
        end
        
        # This is an ugly hack to deal with embedded structures in the spec performer
        class ProcedurePerformerComponent
        include Mongoid::Document
        include FHIR::Element
        include FHIR::Formats::Utilities
            embeds_one :person, class_name:'FHIR::Reference'
            embeds_one :role, class_name:'FHIR::CodeableConcept'
        end
        
        # This is an ugly hack to deal with embedded structures in the spec relatedItem
        class ProcedureRelatedItemComponent
        include Mongoid::Document
        include FHIR::Element
        include FHIR::Formats::Utilities
            
            VALID_CODES = {
                fhirType: [ "caused-by", "because-of" ]
            }
            
            field :fhirType, type: String
            validates :fhirType, :inclusion => { in: VALID_CODES[:fhirType], :allow_nil => true }
            embeds_one :target, class_name:'FHIR::Reference'
        end
        
        # This is an ugly hack to deal with embedded structures in the spec device
        class ProcedureDeviceComponent
        include Mongoid::Document
        include FHIR::Element
        include FHIR::Formats::Utilities
            embeds_one :action, class_name:'FHIR::CodeableConcept'
            embeds_one :manipulated, class_name:'FHIR::Reference'
            validates_presence_of :manipulated
        end
        
        embeds_many :identifier, class_name:'FHIR::Identifier'
        embeds_one :patient, class_name:'FHIR::Reference'
        validates_presence_of :patient
        field :status, type: String
        validates :status, :inclusion => { in: VALID_CODES[:status] }
        validates_presence_of :status
        embeds_one :category, class_name:'FHIR::CodeableConcept'
        embeds_one :fhirType, class_name:'FHIR::CodeableConcept'
        validates_presence_of :fhirType
        embeds_many :bodySite, class_name:'FHIR::Procedure::ProcedureBodySiteComponent'
        embeds_many :indication, class_name:'FHIR::CodeableConcept'
        embeds_many :performer, class_name:'FHIR::Procedure::ProcedurePerformerComponent'
        field :performedDateTime, type: FHIR::PartialDateTime
        embeds_one :performedPeriod, class_name:'FHIR::Period'
        embeds_one :encounter, class_name:'FHIR::Reference'
        embeds_one :location, class_name:'FHIR::Reference'
        embeds_one :outcome, class_name:'FHIR::CodeableConcept'
        embeds_many :report, class_name:'FHIR::Reference'
        embeds_many :complication, class_name:'FHIR::CodeableConcept'
        embeds_many :followUp, class_name:'FHIR::CodeableConcept'
        embeds_many :relatedItem, class_name:'FHIR::Procedure::ProcedureRelatedItemComponent'
        field :notes, type: String
        embeds_many :device, class_name:'FHIR::Procedure::ProcedureDeviceComponent'
        embeds_many :used, class_name:'FHIR::Reference'
        track_history
    end
end
