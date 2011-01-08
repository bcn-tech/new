require 'spec_helper'

describe Position do
  
  context 'associations' do

    it { should belong_to :team }

    it { should have_many :position_questions }

    it { should have_many :questions, :through => :position_questions }

    it { should have_many :applications, :class_name => 'PositionApplication' }

    it { should have_many :contact_emails, :class_name => 'EmailAddress', :as => :addressable }

    it { should accept_nested_attributes_for :position_questions, :contact_emails, :allow_destroy => true }

  end
  
  context 'validations' do

    it { should validate_presence_of :title, :short_description, :duration, :time_commitment, :team, :general_description, :position_description, :applicant_description }

    it { should validate_associated :contact_emails }

    it 'should not require the paid description when unpaid' do
      mock(subject).paid? { false }
      should_not validate_presence_of :paid_description
    end

    it 'should require the paid description when paid' do
      mock(subject).paid? { true }
      should validate_presence_of :paid_description
    end
    
    it 'should ensure the expired at date is before published at' do
      subject.published_at = 2.weeks.ago
      should_not allow_values_for :expires_at, 4.weeks.ago, 2.months.ago, 1.year.ago, subject.published_at
      should allow_values_for :expires_at, (subject.published_at + 1.day), 2.weeks.from_now, nil
    end
    
    it 'should require the contact emails only when published' do
      stub(subject).published? { false }
      should_not validate_presence_of :contact_emails
      stub(subject).published? { true }
      should validate_presence_of :contact_emails
    end

  end
  
  context 'accessible attributes' do
    it { should allow_mass_assignment_of :title, :short_description, :duration, :time_commitment, :team_id, :paid_description, :general_description, :position_description, :applicant_description, :paid, :position_questions_attributes, :contact_emails_attributes }
    it { should_not allow_mass_assignment_of :rendered_paid_description, :rendered_general_description, :rendered_position_description, :rendered_applicant_description }
  end
  
  it_should_behave_like 'a markdown formatted model'
  
  context 'slug generation' do
    
    it 'should automatically generate the slug' do
      Position.make!(:title => 'Marketing Monkey').to_param.should == 'marketing-monkey'
    end
    
    it 'should generate sequential slugs' do
      Position.make!(:title => 'something').to_param.should == 'something'
      Position.make!(:title => 'something').to_param.should == 'something--1'
    end
    
  end
  
  context 'the status of the position' do

    it 'should not be viewable if it is not published' do
      stub(subject).expired?   { false }
      stub(subject).published? { false }
      should_not be_viewable
    end

    it 'should not be viewable if it is expired' do
      stub(subject).expired?   { true }
      stub(subject).published? { true }
      should_not be_viewable
    end

    it 'should be viewable if it is published and not expired' do
      stub(subject).expired?   { false }
      stub(subject).published? { true }
      should be_viewable
    end

    it 'should not be expired when expires_at is in the future' do
      subject.expires_at = 1.week.from_now
      should_not be_expired
    end

    it 'be expired when expires_at is now' do
      t = Time.now
      stub(Time).now { t }
      subject.expires_at = t
      should be_expired
    end

    it 'be expired when expires_at is in the past' do
      subject.expires_at = 1.week.ago
      should be_expired
    end

    it 'should be published when published at is now' do
      t = Time.now
      stub(Time).now { t }
      subject.published_at = t
      should be_published
    end

    it 'should be published when published at is in the past' do
      subject.published_at = 1.week.ago
      should be_published
    end

    it 'should not be published when published at is in the future' do
      subject.published_at = 1.from_now
      should_not be_published
    end

  end

  context 'content conversions' do

    [:paid_description, :general_description, :position_description, :applicant_description].each do |field|

      it "should automatically convert the #{field} on validation" do
        position = Position.make(field => '# Sample Text')
        position.save
        position.send(:"rendered_#{field}").should have_tag(:h1, 'Sample Text')
      end

    end

  end

  context 'position named scopes' do

    before :each do
      @viewable_a     = Position.make!(:published_at => 1.week.ago, :expires_at => 1.week.from_now)
      @viewable_b     = Position.make!(:published_at => 2.months.ago, :expires_at => 2.hours.from_now)
      @expired_a     = Position.make!(:published_at => 2.months.ago, :expires_at => 2.hours.ago)
      @expired_b     = Position.make!(:published_at => nil, :expires_at => 2.weeks.ago)
      @unpublished_a = Position.make!(:published_at => 2.months.from_now, :expires_at => 3.months.from_now)
      @unpublished_b = Position.make!(:published_at => 1.week.from_now, :expires_at => nil)
    end

    it 'should return the correct positions for unpublished' do
      Position.viewable.all.should =~ [@viewable_a, @viewable_b]
    end

    it 'should return the correct positions for unpublished' do
      Position.unpublished.all.should =~ [@unpublished_a, @unpublished_b, @expired_b]
    end

    it 'should return the correct positions for published' do
      Position.published.all.should =~ [@viewable_a, @viewable_b, @expired_a]
    end

    it 'should return the correct positions for expired' do
      Position.expired.all.should =~ [@expired_a, @expired_b]
    end

    it 'should return the correct positions for unexpired' do
      Position.unexpired.all.should =~ [@viewable_a, @viewable_b, @unpublished_a]
    end

  end

  context 'getting the status of a position' do

    it 'should be published when published and unexpired' do
      stub(subject).published? { true }
      stub(subject).expired?   { false }
      subject.status.should == :published
    end

    it 'should be expired when when published and expired' do
      stub(subject).published? { true }
      stub(subject).expired?   { true }
      subject.status.should == :expired
    end

    it 'should be draft when not published' do
      stub(subject).published? { false }
      stub(subject).expired?   { false }
      subject.status.should == :draft
    end

    it 'should let you get the humanised status' do
      with_translations :ui => {:position_status => {:test_status => 'My Test Status'}} do
        mock(subject).status.times(any_times) { :test_status }
        subject.human_status.should == 'My Test Status'
      end
    end

  end

  context 'dealing with position questions' do

    before :each do
      @position = Position.make!
      10.times { @position.position_questions.create :question => Question.make! }
      @questions = @position.questions
    end

    context 'with the association loaded' do

      before :each do
        @position = Position.with_questions.find(@position.id)
      end

      it 'should return a sorted array for ordered' do
        @position.position_questions.ordered.should be_kind_of(Array)
        @position.position_questions.ordered.map(&:order_position) == Array(1..10)
      end

      it 'should not use the database operation' do
        dont_allow(@position.position_questions).maximum
        @position.position_questions.next_order_position
      end

      it 'should return the the correct value for next order position' do
        @position.position_questions.next_order_position.should == 11
      end

      it 'should default to 1 with no order positions' do
        # Same as no values
        stub.instance_of(PositionQuestion).order_position { nil }
        @position.position_questions.next_order_position.should == 1
      end

    end

    context 'without the association loaded' do

      before :each do
        @position = Position.find(@position.id)
      end

      it 'should return a relation for ordered' do
        @position.position_questions.ordered.should be_kind_of(ActiveRecord::Relation)
        @position.position_questions.ordered.map(&:order_position) == Array(1..10)
      end

      it 'should use maximum on the association for the next order position' do
        mock(@position.position_questions).maximum(:order_position) { 10 }
        @position.position_questions.next_order_position.should == 11
      end

      it 'should default to 1 with no order positions' do
        stub(@position.position_questions).maximum(:order_position) { nil }
        @position.position_questions.next_order_position.should == 1
      end

      it 'should return the correct value for the next order position' do
        @position.position_questions.next_order_position.should == 11
      end

    end

  end

  context 'searching on positions' do

    it 'should have a search class method' do
      Position.should respond_to(:search)
    end

    it 'should return a position search object' do
      Position.search.should be_kind_of PositionSearch
    end

    it 'should pass the arguments to Position Search' do
      viewable = Object.new
      mock(Position).viewable { viewable }
      mock(PositionSearch).new viewable, :a => 1
      Position.search :a => 1
    end

  end

  describe 'getting an application reporter' do

    specify { should respond_to(:to_application_reporter) }

    it 'should bu default pass it through with an empty hash' do
      object = Object.new
      mock(PositionApplicationReporter).new(subject, Hash.new) { object }
      subject.to_application_reporter.should == object
    end

    it 'should pass through options when given' do
      object = Object.new
      mock(PositionApplicationReporter).new(subject, :fields => %w(full_name)) { object }
      subject.to_application_reporter(:fields => %w(full_name)).should == object
    end

  end

  describe '#human_time_commitment' do

    let(:position) { Position.new }

    context 'time commitment is nil' do

      before :each do
        position.time_commitment = nil
      end

      it 'has no description' do
        position.human_time_commitment.should == ''
      end

    end

    context 'time commitment of 1 hour' do

      before :each do
        position.time_commitment = :'1_hour'
      end

      it 'has a description of "1 hour"' do
        position.human_time_commitment.should == '1 hour'
      end

    end

    context 'time commitment of a full day' do

      before :each do
        position.time_commitment = :a_full_day
      end

      it 'has a description of "A full day"' do
        position.human_time_commitment.should == 'A full day'
      end

    end

  end

end

# == Schema Information
#
# Table name: positions
#
#  id                             :integer         not null, primary key
#  title                          :string(255)
#  short_description              :text
#  team_id                        :integer
#  paid                           :boolean         default(FALSE)
#  duration                       :string(255)
#  time_commitment                :integer
#  rendered_paid_description      :text
#  rendered_general_description   :text
#  rendered_position_description  :text
#  rendered_applicant_description :text
#  general_description            :text
#  position_description           :text
#  applicant_description          :text
#  paid_description               :text
#  published_at                   :datetime
#  expires_at                     :datetime
#  cached_slug                    :string(255)
#  created_at                     :datetime
#  updated_at                     :datetime
#

