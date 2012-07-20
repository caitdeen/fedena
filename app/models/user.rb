#Fedena
#Copyright 2011 Foradian Technologies Private Limited
#
#This product includes software developed at
#Project Fedena - http://www.projectfedena.org/
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

class User < ActiveRecord::Base
  attr_accessor :password, :role, :old_password, :new_password, :confirm_password

  validates_uniqueness_of :username #, :email
  validates_length_of     :username, :within => 1..20
  validates_length_of     :password, :within => 4..40, :allow_nil => true
  validates_format_of     :username, :with => /^[A-Z0-9_-]*$/i,
    :message => "#{t('must_contain_only_letters')}"
  validates_format_of     :email, :with => /^[A-Z0-9._%-]+@([A-Z0-9-]+\.)+[A-Z]{2,4}$/i,   :allow_blank=>true,
    :message => "#{t('must_be_a_valid_email_address')}"
  validates_presence_of   :role , :on=>:create
  validates_presence_of   :password, :on => :create
  
  has_and_belongs_to_many :privileges

  has_one :student_record,:class_name=>"Student",:foreign_key=>"user_id"
  has_one :employee_record,:class_name=>"Employee",:foreign_key=>"user_id"

  def before_save
    self.salt = random_string(8) if self.salt == nil
    self.hashed_password = Digest::SHA1.hexdigest(self.salt + self.password) unless self.password.nil?
    if self.new_record?
      self.admin, self.student, self.employee = false, false, false
      self.admin    = true if self.role == 'Admin'
      self.student  = true if self.role == 'Student'
      self.employee = true if self.role == 'Employee'
      self.parent = true if self.role == 'Parent'
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def check_reminders
    reminders =[]
    reminders = Reminder.find(:all , :conditions => ["recipient = '#{self.id}'"])
    count = 0
    reminders.each do |r|
      unless r.is_read
        count += 1
      end
    end
    return count
  end

  def self.authenticate?(username, password)
    u = User.find_by_username username
    u.hashed_password == Digest::SHA1.hexdigest(u.salt + password)
  end

  def random_string(len)
    randstr = ""
    chars = ("0".."9").to_a + ("a".."z").to_a + ("A".."Z").to_a
    len.times { randstr << chars[rand(chars.size - 1)] }
    randstr
  end

  def role_name
    return "#{t('admin')}" if self.admin?
    return "#{t('student_text')}" if self.student?
    return "#{t('employee_text')}" if self.employee?
    return "#{t('parent')}" if self.parent?
    return nil
  end
  
  def role_symbols
    prv = []
    @privilge_symbols ||= privileges.map { |privilege| prv << privilege.name.underscore.to_sym }

    if admin?
      return [:admin] + prv
    elsif student?
      return [:student] + prv
    elsif employee?
      employee = employee_record
      unless employee.nil?
        if employee.subjects.present?
          prv << :subject_attendance if Configuration.get_config_value('StudentAttendanceType') == 'SubjectWise'
          prv << :subject_exam
        end
        if Batch.active.collect(&:employee_id).include?(employee.id.to_s)
          prv << :view_results
        end
      end
      return [:employee] + prv
    elsif parent?
      return [:parent] + prv
    else
      return prv
    end
  end

  def clear_menu_cache
    Rails.cache.delete("user_main_menu#{self.id}")
    Rails.cache.delete("user_autocomplete_menu#{self.id}")
  end

  def parent_record
    Student.find_by_admission_no(self.username[1..self.username.length])
  end
  
  def has_subject_in_batch(b)
    employee_record.subjects.collect(&:batch_id).include? b.id
  end
end
